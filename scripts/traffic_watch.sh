#!/bin/sh

HOST="$1"
PORT="$2"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <host> <port>" >&2
  exit 1
fi

LAN_PREFIX="${LAN_PREFIX:-192.168.8.}"
IGNORE_IPS="${IGNORE_IPS:-$HOST 192.168.8.1}"
WHATSAPP_IPS="/tmp/cybershow_whatsapp_ips.txt"
WA_LAST="/tmp/cybershow_wa_last.txt"

: > "$WHATSAPP_IPS"
: > "$WA_LAST"

send_event() {
    JSON="$1"
    echo "$JSON" >&2
    { echo "$JSON"; sleep 0.2; } | nc "$HOST" "$PORT" >/dev/null 2>&1
}

# ── Learn WhatsApp server IPs from dnsmasq log ────────────────────────────────
# Populates WHATSAPP_IPS so the packet watcher can correlate port-443 traffic.
ip_learner() {
    logread -f | grep -Ei 'whatsapp|wa\.me' | while read -r line; do
        for token in $line; do
            ip="$(printf '%s' "$token" | sed -n 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)[^0-9]*/\1/p')"
            [ -z "$ip" ] && continue
            case "$ip" in
                "$LAN_PREFIX"*|0.*|10.*|127.*|169.254.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|192.168.*)
                    continue ;;
            esac
            grep -Fxq "$ip" "$WHATSAPP_IPS" 2>/dev/null || echo "$ip" >> "$WHATSAPP_IPS"
        done
    done
}

# ── DNS traffic watcher ───────────────────────────────────────────────────────
# Forwards raw DNS query events to the app. Classification happens in the app.
dns_watcher() {
    while true; do
        logread -f | grep dnsmasq | awk -f /root/cybershow_events.awk | tee /dev/stderr | nc "$HOST" "$PORT"
        echo "dns_watcher: connection lost, reconnecting in 2s..." >&2
        sleep 2
    done
}

# ── WhatsApp packet watcher ───────────────────────────────────────────────────
# Detects WhatsApp traffic via dedicated ports (5222/5223/5228/4244) or via
# port-443 connections to known WhatsApp server IPs. Emits raw traffic events
# using wa.me as the domain; the app classifies those as WHATSAPP.
packet_watcher() {
    while true; do
        tcpdump -l -n -q -i any \
            'tcp and (port 443 or port 5222 or port 5223 or port 5228 or port 4244)' \
            2>/dev/null | \
        while read -r line; do
            PAIR="$(printf '%s' "$line" | sed -n \
                's/.*IP \([0-9][0-9.]*\)\.[0-9][0-9]* > \([0-9][0-9.]*\)\.[0-9][0-9]*:.*/\1 \2/p')"
            [ -z "$PAIR" ] && continue

            set -- $PAIR
            SRC="$1"; DST="$2"
            LAN_IP=""; REMOTE_IP=""

            case "$SRC" in "$LAN_PREFIX"*) LAN_IP="$SRC"; REMOTE_IP="$DST" ;; esac
            [ -z "$LAN_IP" ] && case "$DST" in
                "$LAN_PREFIX"*) LAN_IP="$DST"; REMOTE_IP="$SRC" ;;
            esac
            [ -z "$LAN_IP" ] && continue

            for ignore in $IGNORE_IPS; do
                [ "$LAN_IP" = "$ignore" ] && LAN_IP="" && break
            done
            [ -z "$LAN_IP" ] && continue

            # Per-IP cooldown: 3 seconds
            NOW="$(date +%s)"
            LAST="$(awk -F'|' -v ip="$LAN_IP" '$1==ip{print $2;exit}' "$WA_LAST" 2>/dev/null)"
            [ -n "$LAST" ] && [ $((NOW - LAST)) -lt 3 ] && continue
            awk -F'|' -v ip="$LAN_IP" '$1!=ip{print}' "$WA_LAST" 2>/dev/null > "$WA_LAST.tmp"
            printf '%s|%s\n' "$LAN_IP" "$NOW" >> "$WA_LAST.tmp"
            mv "$WA_LAST.tmp" "$WA_LAST"

            is_wa=0
            case "$line" in
                *".5222:"*|*".5223:"*|*".5228:"*|*".4244:"*) is_wa=1 ;;
                *".443:"*) grep -Fxq "$REMOTE_IP" "$WHATSAPP_IPS" 2>/dev/null && is_wa=1 ;;
            esac
            [ "$is_wa" -eq 0 ] && continue

            send_event "{\"type\":\"traffic\",\"domain\":\"wa.me\",\"ip\":\"$LAN_IP\",\"ts\":$NOW}"
        done

        echo "packet_watcher: tcpdump exited, restarting in 5s..." >&2
        sleep 5
    done
}

echo "Starting traffic watcher to $HOST:$PORT..." >&2

ip_learner &
IP_LEARNER_PID="$!"

dns_watcher &
DNS_PID="$!"

packet_watcher &
PACKET_PID="$!"

trap 'kill "$IP_LEARNER_PID" "$DNS_PID" "$PACKET_PID" 2>/dev/null; exit 0' INT TERM

wait
