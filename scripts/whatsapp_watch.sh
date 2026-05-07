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
LAST_EVENT="/tmp/cybershow_whatsapp_last_event.txt"

: > "$WHATSAPP_IPS"
: > "$LAST_EVENT"

send_event() {
    IP="$1"
    DOMAIN="$2"
    NOW="$(date +%s)"

    for ignore in $IGNORE_IPS; do
        if [ "$IP" = "$ignore" ]; then
            return
        fi
    done

    LAST="$(awk -F'|' -v ip="$IP" '$1 == ip { print $2; exit }' "$LAST_EVENT" 2>/dev/null)"
    if [ -n "$LAST" ] && [ $((NOW - LAST)) -lt 3 ]; then
        return
    fi

    awk -F'|' -v ip="$IP" '$1 != ip { print }' "$LAST_EVENT" 2>/dev/null > "$LAST_EVENT.tmp"
    echo "$IP|$NOW" >> "$LAST_EVENT.tmp"
    mv "$LAST_EVENT.tmp" "$LAST_EVENT"

    JSON_MSG="{\"event\":\"WHATSAPP\",\"domain\":\"$DOMAIN\",\"ip\":\"$IP\"}"
    echo "$JSON_MSG" >&2
    { echo "$JSON_MSG"; sleep 0.2; } | nc "$HOST" "$PORT" >/dev/null 2>&1
}

learn_whatsapp_ips() {
    logread -f | grep -Ei 'whatsapp|wa\.me' | while read -r line; do
        for token in $line; do
            ip="$(echo "$token" | sed -n 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)[^0-9]*/\1/p')"
            [ -z "$ip" ] && continue
            case "$ip" in
                "$LAN_PREFIX"*|0.*|10.*|127.*|169.254.*|172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*|192.168.*)
                    continue
                    ;;
            esac
            grep -Fxq "$ip" "$WHATSAPP_IPS" 2>/dev/null || echo "$ip" >> "$WHATSAPP_IPS"
        done
    done
}

learn_whatsapp_ips &
LOGGER_PID="$!"

trap 'kill "$LOGGER_PID" 2>/dev/null; exit 0' INT TERM EXIT

echo "Starting WhatsApp packet watcher to $HOST:$PORT..." >&2

tcpdump -l -n -q -i any 'tcp and (port 443 or port 5222 or port 5223 or port 5228 or port 4244)' 2>/dev/null \
| while read -r line; do
    PAIR="$(echo "$line" | sed -n 's/.*IP \([0-9][0-9.]*\)\.[0-9][0-9]* > \([0-9][0-9.]*\)\.[0-9][0-9]*:.*/\1 \2/p')"
    [ -z "$PAIR" ] && continue

    set -- $PAIR
    SRC="$1"
    DST="$2"
    LAN_IP=""
    REMOTE_IP=""

    case "$SRC" in
        "$LAN_PREFIX"*) LAN_IP="$SRC"; REMOTE_IP="$DST" ;;
    esac
    if [ -z "$LAN_IP" ]; then
        case "$DST" in
            "$LAN_PREFIX"*) LAN_IP="$DST"; REMOTE_IP="$SRC" ;;
        esac
    fi

    [ -z "$LAN_IP" ] && continue

    case "$line" in
        *".5222:"*|*".5223:"*|*".5228:"*|*".4244:"*)
            send_event "$LAN_IP" "whatsapp-packet"
            ;;
        *".443:"*)
            if grep -Fxq "$REMOTE_IP" "$WHATSAPP_IPS" 2>/dev/null; then
                send_event "$LAN_IP" "whatsapp-443"
            fi
            ;;
    esac
done
