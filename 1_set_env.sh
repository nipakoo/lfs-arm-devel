#!/bin/bash

# USAGE EXAMPLE: source 1_set_env.sh

export LFS=/mnt/lfs
export LC_ALL=POSIX
export LFS_TGT=$(uname -m)-lfs-linux-gnueabihf
export PATH=/tools/bin:/bin:/usr/bin
export MAKEFLAGS='-j 4'
export FORCE_UNSAFE_CONFIGURE=1

