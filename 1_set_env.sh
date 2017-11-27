#!/bin/bash

# USAGE EXAMPLE: source 1_set_env.sh

export LFS=/mnt/lfs
export LC_ALL=POSIX
# TODO CHECK THIS ARCH CONFIG GUESSIL
export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=/tools/bin:/bin:/usr/bin
export MAKEFLAGS='-j 4'

