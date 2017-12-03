The included scripts can be used to build your own LFS system on an arm device. The installation has been carried on a Raspberry Pi 3 Model B with a 16GB micro SD.

Everything here is based on the Linux From Scratch project documentation http://www.linuxfromscratch.org/. The guide used as base is LFS systemd development version 20171126. It is advisable to at least scramble through the beginning of this material in order to make sure certain requirements are met.

Usage:
- run scripts in ascending order as root
- use another linux system to prepare a target partition for installation on your sd card, we need around 6GB partition in /dev/mmcblk0p3
- run the second to the fifth scripts (1_set_env.sh, 2_fetch_sources.sh, 3_build_tools.sh, 4_prepare_lfs.sh) on an already installed linux system on the target device
- run the fifth and the sixth scripts (5_build_lfs.sh and 6_configure_lfs.sh) in a chroot of target system
- run the seventh script (7_finalize.sh) in the host system to unmount the virtual file systems and reboot

Notes:
- if you stop midst 3_build_tools.sh and come back to a new session, remember to rerun 1_set_env.sh
- if you stop midst 5_build_lfs.sh and come back to a new session, remember to rerun 4_prepare_lfs.sh
- while running tests is recommended by LFS documentation these scripts do not run ANY

TODO:
- add make error checking
- generalize package_build functions by receiving arguments for configure
- due to changing of shell, split script number five into two: before and after bash build, REMEMBER TO SET MAKEFLAGS
- add check to make sure all sources are downloaded and verify checksums

This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.

