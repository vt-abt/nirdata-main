#!/bin/bash
set -e
WORK_DIR="/tmp/nirdata_iso_build"
ROOTFS="${WORK_DIR}/rootfs"

echo "[*] Setting up Alpine Environment..."
mkdir -p $ROOTFS

apk add --root ${ROOTFS} --initdb --keys-dir /etc/apk/keys alpine-base
cat <<EOF | chroot ${ROOTFS} /bin/sh
apk update
apk add --no-cache \
    python3 py3-pip hdparm nvme-cli sg3_utils \
    android-tools syslinux util-linux pciutils
pip install fastapi uvicorn web3 torch numpy pure-python-adb
EOF

echo "[*] Injecting NirData Logic..."

cp ../core-desc/target/x86_64-unknown-linux-musl/release/nirdata-core ${ROOTFS}/usr/bin/
cp -r ../server ${ROOTFS}/opt/nirdata-api

echo "[*] Packaging Live System..."
