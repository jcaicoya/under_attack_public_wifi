#!/bin/sh

HOST="$1"
PORT="$2"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <host> <port>" >&2
  exit 1
fi

STATE_FILE="/tmp/cybershow_wifi_inventory.txt"
NEXT_STATE_FILE="/tmp/cybershow_wifi_inventory_next.txt"
SNAPSHOT_EVERY="${SNAPSHOT_EVERY:-5}"
LOOP_SLEEP="${LOOP_SLEEP:-1}"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

get_wifi_interfaces() {
    iw dev 2>/dev/null | awk '/Interface/ { print $2 }' | awk 'NF && !seen[$1]++'
}

# Returns 0 if any wireless interface is usable (cfg80211 or RA-series)
has_wifi_interface() {
    [ -n "$(get_wifi_interfaces)" ] && return 0
    iwinfo ra0 info >/dev/null 2>&1 && return 0
    iwinfo rai0 info >/dev/null 2>&1 && return 0
    return 1
}

get_wifi_records() {
    iw_ifaces="$(get_wifi_interfaces)"

    if [ -n "$iw_ifaces" ]; then
        for iface in $iw_ifaces; do
            iw dev "$iface" station dump 2>/dev/null \
            | awk -v iface="$iface" '
                /^Station[[:space:]][0-9A-Fa-f:]{17}/ {
                    if (mac != "" && mac != "00:00:00:00:00:00")
                        print toupper(mac) "|" signal "|" iface
                    mac=$2
                    signal=""
                }
                /^[[:space:]]*signal:/ {
                    signal=$2
                }
                END {
                    if (mac != "" && mac != "00:00:00:00:00:00")
                        print toupper(mac) "|" signal "|" iface
                }
            '
        done | sort -u
        return
    fi

    # Fallback: RA-series proprietary driver (GL-MT300N-V2, iwinfo assoclist)
    for iface in ra0 rai0; do
        iwinfo "$iface" assoclist 2>/dev/null \
        | awk -v iface="$iface" '
            length($1) == 17 && substr($1, 3, 1) == ":" {
                mac = toupper($1)
                signal = $2
                if (mac != "00:00:00:00:00:00")
                    print mac "|" signal "|" iface
            }
        '
    done | sort -u
}

resolve_dhcp() {
    MAC="$1"
    awk -v mac="$MAC" '
        BEGIN { IGNORECASE=1 }
        toupper($2) == toupper(mac) {
            ip=$3
            name=$4
            if (name == "*") name=""
            printf "%s|%s\n", name, ip
            exit
        }
    ' /tmp/dhcp.leases 2>/dev/null
}

resolve_neigh_ip() {
    MAC="$1"
    ip neigh show 2>/dev/null \
    | awk -v mac="$MAC" '
        BEGIN { IGNORECASE=1 }
        toupper($0) ~ toupper(mac) {
            print $1
            exit
        }
    '
}

build_inventory() {
    wifi_records="$(get_wifi_records)"

    if [ -z "$wifi_records" ]; then
        # Only use DHCP leases when no wifi interface is present at all.
        # If wifi is present but has no stations, the inventory is genuinely empty —
        # falling back to DHCP leases would prevent disconnect events from ever being sent.
        if ! has_wifi_interface; then
            build_inventory_from_leases
        fi
        return
    fi

    printf '%s\n' "$wifi_records" | while IFS='|' read -r mac signal iface; do
        [ -z "$mac" ] && continue

        dhcp="$(resolve_dhcp "$mac")"
        name="$(printf '%s' "$dhcp" | cut -d'|' -f1)"
        ip="$(printf '%s' "$dhcp" | cut -d'|' -f2)"
        source="wifi:$iface"

        if [ -n "$ip" ]; then
            source="wifi:$iface+dhcp"
        else
            ip="$(resolve_neigh_ip "$mac")"
            if [ -n "$ip" ]; then
                source="wifi:$iface+neigh"
            fi
        fi

        printf '%s|%s|%s|%s|%s\n' "$mac" "$ip" "$name" "$signal" "$source"
    done | sort -u
}

build_inventory_from_leases() {
    awk '
        NF >= 3 {
            mac=toupper($2)
            ip=$3
            name=$4
            if (name == "*") name=""
            if (mac != "" && mac != "00:00:00:00:00:00")
                print mac "|" ip "|" name "||dhcp"
        }
    ' /tmp/dhcp.leases 2>/dev/null | sort -u
}

record_json() {
    record="$1"
    mac="$(printf '%s' "$record" | cut -d'|' -f1)"
    ip="$(printf '%s' "$record" | cut -d'|' -f2)"
    name="$(printf '%s' "$record" | cut -d'|' -f3)"
    signal="$(printf '%s' "$record" | cut -d'|' -f4)"
    source="$(printf '%s' "$record" | cut -d'|' -f5)"

    mac_json="$(json_escape "$mac")"
    ip_json="$(json_escape "$ip")"
    name_json="$(json_escape "$name")"
    source_json="$(json_escape "$source")"

    case "$signal" in
        -[0-9]*|[0-9]*) signal_json="$signal" ;;
        *) signal_json="null" ;;
    esac

    printf '{"mac":"%s","ip":"%s","name":"%s","device":"%s","signal":%s,"source":"%s","connected":true}' \
        "$mac_json" "$ip_json" "$name_json" "$name_json" "$signal_json" "$source_json"
}

send_json() {
    json="$1"
    echo "$json" >&2
    { echo "$json"; sleep 0.2; } | nc "$HOST" "$PORT" >/dev/null 2>&1
}

send_snapshot() {
    file="$1"
    json='{"type":"device","action":"snapshot","devices":['
    first=1

    while IFS= read -r record; do
        [ -z "$record" ] && continue
        if [ "$first" -eq 0 ]; then
            json="$json,"
        fi
        json="$json$(record_json "$record")"
        first=0
    done < "$file"

    json="$json]}"
    send_json "$json"
}

send_change_event() {
    action="$1"
    record="$2"
    mac="$(printf '%s' "$record" | cut -d'|' -f1)"
    ip="$(printf '%s' "$record" | cut -d'|' -f2)"
    name="$(printf '%s' "$record" | cut -d'|' -f3)"
    signal="$(printf '%s' "$record" | cut -d'|' -f4)"
    source="$(printf '%s' "$record" | cut -d'|' -f5)"

    mac_json="$(json_escape "$mac")"
    ip_json="$(json_escape "$ip")"
    name_json="$(json_escape "$name")"
    source_json="$(json_escape "$source")"

    case "$signal" in
        -[0-9]*|[0-9]*) signal_json="$signal" ;;
        *) signal_json="null" ;;
    esac

    send_json "$(printf '{"type":"device","action":"%s","mac":"%s","ip":"%s","name":"%s","device":"%s","signal":%s,"source":"%s"}' \
        "$action" "$mac_json" "$ip_json" "$name_json" "$name_json" "$signal_json" "$source_json")"
}

find_by_mac() {
    mac="$1"
    file="$2"
    awk -F'|' -v mac="$mac" 'toupper($1) == toupper(mac) { print; exit }' "$file" 2>/dev/null
}

echo "Starting device inventory watcher to $HOST:$PORT..." >&2

build_inventory > "$STATE_FILE"
send_snapshot "$STATE_FILE"
ticks=0

while true; do
    sleep "$LOOP_SLEEP"
    build_inventory > "$NEXT_STATE_FILE"
    changed=0

    while IFS= read -r record; do
        [ -z "$record" ] && continue
        mac="$(printf '%s' "$record" | cut -d'|' -f1)"
        old="$(find_by_mac "$mac" "$STATE_FILE")"

        if [ -z "$old" ]; then
            send_change_event "connected" "$record"
            changed=1
        elif [ "$old" != "$record" ]; then
            send_change_event "updated" "$record"
            changed=1
        fi
    done < "$NEXT_STATE_FILE"

    while IFS= read -r record; do
        [ -z "$record" ] && continue
        mac="$(printf '%s' "$record" | cut -d'|' -f1)"
        if [ -z "$(find_by_mac "$mac" "$NEXT_STATE_FILE")" ]; then
            send_change_event "disconnected" "$record"
            changed=1
        fi
    done < "$STATE_FILE"

    mv "$NEXT_STATE_FILE" "$STATE_FILE"
    ticks=$((ticks + 1))

    if [ "$changed" -eq 1 ] || [ "$ticks" -ge "$SNAPSHOT_EVERY" ]; then
        send_snapshot "$STATE_FILE"
        ticks=0
    fi
done
