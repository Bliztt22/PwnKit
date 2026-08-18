#!/bin/bash
# Wait for SSH then open a session
set -e
HOST=127.0.0.1
PORT=2222

echo "[*] Waiting for SSH on ${HOST}:${PORT} …"
for i in $(seq 1 180); do
  if nc -z -w 2 "$HOST" "$PORT" 2>/dev/null; then
    sleep 2
    echo "[+] SSH is up — connecting (lab / lab)"
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" lab@"$HOST"
  fi
  printf "."
  sleep 3
done
echo
echo "[-] Timeout — is the VM running? (docker compose up target)"
exit 1
