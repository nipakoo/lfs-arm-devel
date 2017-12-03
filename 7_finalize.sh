#!/bin/bash

# USAGE EXAMPLE: ./7_finalize.sh


if [ -z ${LFS} ]; then
	echo "Required environment variable 'LFS' is empty"
	exit 1
fi

# Backup PI kernel and take newly built kernel into use
cp -r /boot /home/
mv ${LFS}/boot/* /boot/

# Configure to boot into the new root filesystem
ROOT=$(cat /boot/cmdline.txt | sed -e 's/^.*root=//' -e 's/ .*$//')
sed -i "s/$ROOT/\/dev\/mmcblk0p3/g" /boot/cmdline.txt

cat > ${LFS}/etc/fstab << "EOF"
proc               /proc     proc     defaults             0   0
/dev/mmcblk0p1     /boot     vfat    defaults             0   2
/dev/mmcblk0p3     /         ext4     defaults,noatime     0   1
EOF

umount ${LFS}/dev/pts
umount ${LFS}/dev
umount ${LFS}/run
umount ${LFS}/proc
umount ${LFS}/sys

umount ${LFS}

/sbin/shutdown -r now

