set -e

BUILD_DIR="./build_iso"
OS_ROOT="${BUILD_DIR}/rootfs"

echo "[*] Constructing Clean Alpine Root..."
apk add --root ${OS_ROOT} --initdb --keys-dir /etc/apk/keys alpine-base
chroot ${OS_ROOT} /bin/sh -c "apk add hdparm sg3_utils nvme-cli python3 py3-pytorch-cpu"

echo "[*] Injecting NirData Binary..."
cp ../core-engine-rs/target/release/nirdata-core ${OS_ROOT}/usr/bin/

echo "[*] Configuring Live Init..."
cat <<EOF > ${OS_ROOT}/etc/init.d/nirdata-autoloader
#!/sbin/openrc-run
command="/usr/bin/nirdata-core"
command_args="/dev/sda" # Automated target scanning logic goes here
EOF

echo "[*] Packaging SquashFS..."
mksquashfs ${OS_ROOT} ${BUILD_DIR}/alpine.sqsh -noappend -comp xz

echo "[*] Finalizing Bootable ISO: NirData_Live_v1.0.iso"