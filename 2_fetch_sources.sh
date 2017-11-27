#!/bin/bash

# USAGE EXAMPLE: ./2_fetch_sources.sh /dev/sdd

TARGET_PARTITION=$1

# mount the target device
mkdir ${LFS}
mount -t ext4 ${TARGET_PARTITION} ${LFS}

# fetch needed sources and leave wget-list for future use
mkdir ${LFS}/sources
curl -O http://www.linuxfromscratch.org/lfs/view/systemd/wget-list
wget --input-file=wget-list --continue --directory-prefix=${LFS}/sources

# verify source checksums
pushd ${LFS}/sources
curl -O http://www.linuxfromscratch.org/lfs/view/systemd/md5sums
md5sum -c md5sums
rm -f md5sums
popd

