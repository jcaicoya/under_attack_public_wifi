#!/bin/sh

HOST="$1"
PORT="$2"

if [ -z "$HOST" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <host> <port>"
  exit 1
fi

echo "Starting traffic event watcher to $HOST:$PORT..." >&2

while true; do
  # Logread pipes to grep, which pipes to awk
  # awk pipes to tee, which mirrors output to stderr (visible via SSH) and stdout (piped to nc)
  logread -f | grep dnsmasq | awk -f /root/cybershow_events.awk | tee /dev/stderr | nc "$HOST" "$PORT"
  
  echo "Connection to $HOST:$PORT dropped or logread exited. Reconnecting in 2 seconds..." >&2
  sleep 2
done