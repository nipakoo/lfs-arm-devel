#!/bin/bash

# USAGE EXAMPLE: ./7_finalize.sh


if [ -z ${LFS} ]; then
	echo "Required environment variable 'LFS' is empty"
	exit 1
fi

umount ${LFS}/dev/pts
umount ${LFS}/dev
umount ${LFS}/run
umount ${LFS}/proc
umount ${LFS}/sys

umount ${LFS}

/sbin/shutdown -r now

