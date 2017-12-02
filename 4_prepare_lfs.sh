#!/bin/bash

# USAGE EXAMPLE: ./4_prepare_lfs.sh

mkdir -p ${LFS}/{dev,proc,sys,run}

mknod -m 600 ${LFS}/dev/console c 5 1
mknod -m 666 ${LFS}/dev/null c 1 3

mount --bind /dev ${LFS}/dev
mount -t devpts devpts ${LFS}/dev/pts -o gid=5,mode=620
mount -t proc proc ${LFS}/proc
mount -t sysfs sysfs ${LFS}/sys
mount -t tmpfs tmpfs ${LFS}/run

if [ -h ${LFS}/dev/shm ]; then
  mkdir -pv ${LFS}/$(readlink ${LFS}/dev/shm)
fi

cp 5_build_lfs.sh ${LFS}/tools
cp 6_configure_lfs.sh ${LFS}/tools
cp 7_finalize.sh ${LFS}/tools
cp utilities.sh ${LFS}/tools

chroot "${LFS}" /tools/bin/env -i             \
		HOME=/root                  \
		TERM="${TERM}"                \
		PS1='(lfs chroot) \u:\w\$ ' \
		PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
		/tools/bin/bash --login +h

