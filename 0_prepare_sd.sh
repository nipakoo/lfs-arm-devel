#!/bin/bash

# USAGE EXAMPLE: ./0_prepare_sd.sh /dev/sdc

MICRO_SD_DEV=$1

# shrink current root fs on micro SD to 6GB
umount ${MICRO_SD_DEV}
if ! [[ fsck -f ${MICRO_SD_DEV} ]]; then
	echo "Filesystem check failed!"
	exit 1
fi

resize2fs ${MICRO_SD_DEV} 6GB

# create a new 10GB partition and fs
parted -a optimal ${MICRO_SD_DEV} mkpart primary 6GB 16GB
mkfs -v -t ext4 ${MICRO_SD_DEV}

