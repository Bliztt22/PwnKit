#!/bin/bash
# Wait until SSH on localhost:2222 accepts connections
set -e
HOST="${1:-127.0.0.1}"
PORT="${2:-2222}"
echo "[*] Waiting for SSH on ${HOST}:${PORT} …"
for i in $(seq 1 120); do
  if nc -z -w 2 "$HOST" "$PORT" 2>/dev/null; then
    # Extra second for sshd to fully start
    sleep 2
    echo "[+] SSH is up"
    exit 0
  fi
  sleep 3
done
echo "[-] Timeout waiting for SSH"
exit 1
