The included scripts can be used to build your own LFS system on an arm device. The installation has been carried on a Raspberry Pi 3 Model B with a 16GB micro SD.

Everything here is based on the Linux From Scratch project documentation http://www.linuxfromscratch.org/. The guide used as base is LFS systemd development version 20171126. It is advisable to at leastscramble through the beginning in order to make sure certain requirements are met.

Usage:
- run scripts in order (1 -> 6) as root
- run the first script (0_prepare_sd.sh) on another linux system with the target micro SD accessible
- run the second to the fifth scripts (1_set_env.sh, 2_fetch_sources.sh, 3_build_tools.sh, 4_prepare_lfs.sh) on an already installed linux system on the target device
- run the sixth and the seventh scripts (5_build_lfs.sh, 6_configure_lfs.sh) in a chroot of target system

Notes:
- if you stop midst 3_build_tools.sh and come back to a new session, remember to rerun 1_set_env.sh
- if you stop midst 5_build_lfs.sh and come back to a new session, remember to rerun 4_prepare_lfs.sh
- while running tests is recommended by LFS documentation these scripts do not run ANY

This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
