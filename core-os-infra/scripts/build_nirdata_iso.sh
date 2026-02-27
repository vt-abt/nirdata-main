set -e

# Configuration
DISTRO="alpine"
VERSION="3.18"
ARCH="x86_64"
WORK_DIR="/tmp/nirdata_iso_build"
ISO_NAME="NirData_Live_v1_0_Sepolia.iso"

echo "TASK: INITIALIZING BUILD ENVIRONMENT"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "TASK: FETCHING BASE SYSTEM ROOTFS"
curl -O https://dl-cdn.alpinelinux.org/alpine/v${VERSION}/releases/${ARCH}/alpine-minirootfs-${VERSION}.0-${ARCH}.tar.gz
mkdir -p rootfs
tar -xzf alpine-minirootfs-*.tar.gz -C rootfs/

echo "TASK: INSTALLING SYSTEM DEPENDENCIES (CHROOT)"
mount -t proc /proc rootfs/proc
mount -t sysfs /sys rootfs/sys
mount -o bind /dev rootfs/dev

cat <<EOF | chroot rootfs /bin/sh
apk update
apk add --no-cache \
    linux-lts \
    syslinux \
    busybox-initscripts \
    python3 \
    py3-pip \
    hdparm \
    nvme-cli \
    sg3_utils \
    pciutils \
    libc6-compat
pip install --no-cache-dir fastapi uvicorn web3 torch numpy
EOF

echo "TASK: INJECTING NIRDATA CORE ENGINE"
# Assuming Rust engine has been compiled for musl target
cp /workspace/core-engine-rs/target/x86_64-unknown-linux-musl/release/nirdata-core rootfs/usr/bin/
chmod +x rootfs/usr/bin/nirdata-core

echo "TASK: CONFIGURING BOOT SERVICES"
# Set the FastAPI glue and Rust engine to run on startup
cat <<EOF > rootfs/etc/local.d/nirdata.start
#!/bin/sh
# Initialize Hardware Wiping Bridge
cd /opt/nirdata-api && uvicorn main:app --host 0.0.0.0 --port 8000 &
# Start Frontend Dashboard (Minimal Python Webserver)
cd /opt/nirdata-frontend && python3 -m http.server 80 &
EOF
chmod +x rootfs/etc/local.d/nirdata.start

echo "TASK: PREPARING BOOT INFRASTRUCTURE"
# Build the actual boot infrastructure
chroot rootfs mkinitfs -o /boot/initramfs-lts

echo "TASK: PREPARING ISO CONTENT STRUCTURE"
mkdir -p iso_content/boot
cp rootfs/boot/vmlinuz-lts iso_content/boot/
cp rootfs/boot/initramfs-lts iso_content/boot/
mksquashfs rootfs iso_content/boot/rootfs.sqsh -comp xz

echo "TASK: CONFIGURING ISOLINUX BOOTLOADER"
mkdir -p iso_content/boot/isolinux
cat <<EOF > iso_content/boot/isolinux/isolinux.cfg
default nirdata
label nirdata
  kernel /boot/vmlinuz-lts
  append initrd=/boot/initramfs-lts modules=loop,squashfs,sd-mod,usb-storage quiet copytoram
EOF

echo "TASK: GENERATING FINAL ISO IMAGE"
xorriso -as mkisofs -l -J -R -V "NIRDATA_LIVE" \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
    -o ../$ISO_NAME iso_content/

echo "BUILD COMPLETE: ../$ISO_NAME"

#cleanup
umount rootfs/dev || true
umount rootfs/sys || true
umount rootfs/proc || true