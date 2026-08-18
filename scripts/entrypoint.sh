#!/bin/bash
set -euo pipefail

IMAGES=/lab/images
IMG="$IMAGES/centos7-pwnkit.qcow2"
SEED="$IMAGES/seed.iso"
BASE_URL="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-2009.qcow2"
RAM="${QEMU_RAM:-1024}"
CPUS="${QEMU_CPUS:-2}"

mkdir -p "$IMAGES"

# ---------- 1. Download base image once ----------
if [ ! -f "$IMG" ]; then
  echo "[*] Downloading CentOS 7 GenericCloud image (~850 MB)…"
  echo "    $BASE_URL"
  curl -fL --progress-bar -o "$IMG.partial" "$BASE_URL"
  mv "$IMG.partial" "$IMG"
  echo "[+] Image saved: $IMG"
fi

# ---------- 2. Build cloud-init seed ISO ----------
echo "[*] Building cloud-init seed ISO…"
cloud-localds "$SEED" /lab/cloud-init/user-data /lab/cloud-init/meta-data

# ---------- 3. Choose acceleration ----------
ACCEL_ARGS=()
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  echo "[+] KVM available — using hardware acceleration"
  ACCEL_ARGS=(-enable-kvm -cpu host)
else
  echo "[!] No KVM — using TCG (slower, first boot ~2-5 min)"
  ACCEL_ARGS=(-accel tcg,thread=multi -cpu qemu64)
fi

# ---------- 4. Launch QEMU ----------
echo "[*] Starting QEMU (RAM=${RAM}M CPUs=${CPUS})"
echo "[*] SSH will be forwarded: host:2222 → guest:22"
echo "[*] Login: lab / lab"
echo

exec qemu-system-x86_64 \
  "${ACCEL_ARGS[@]}" \
  -m "$RAM" \
  -smp "$CPUS" \
  -drive file="$IMG",if=virtio,format=qcow2,cache=writeback \
  -drive file="$SEED",if=virtio,format=raw,cache=writeback \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial mon:stdio \
  -name pwnkit-centos7
