#!/bin/bash

# USAGE EXAMPLE: ./6_configure_lfs.sh irma

HOSTNAME=$1

# configure static ip
cat > /etc/systemd/network/10-eth0-static.network << "EOF"
[Match]
Name=eth0

[Network]
Address=192.168.0.2/24
Gateway=192.168.0.1
DNS=192.168.0.1
Domains=<Your Domain Name>
EOF

# configure dhcp
cat > /etc/systemd/network/10-eth0-dhcp.network << "EOF"
[Match]
Name=eth0

[Network]
DHCP=ipv4

[DHCP]
UseDomains=true
EOF

# use systemd-resolved for dns config
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# name you host
echo "${HOSTNAME}" > /etc/hostname

# hosts config
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost
127.0.1.1 <FQDN> <HOSTNAME>
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

# keyboard and console config
cat > /etc/vconsole.conf << "EOF"
KEYMAP=fi
FONT=Lat2-Terminus16
EOF

# write locale conf
cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF

# write readline config
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

# write shell list config
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

# write fstab
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sdd2      /            ext4     defaults            1     1

# End /etc/fstab
EOF

# configure grub
grub-install /dev/sdd

cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,2)

menuentry "GNU/Linux, Linux 4.14-lfs-20171126-systemd" {
        linux   /boot/vmlinuz-4.14-lfs-20171126-systemd root=/dev/sdd2 ro
}
EOF

# write release files
cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="20171126-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 20171126-systemd"
VERSION_CODENAME="albertinos"
EOF

echo 20171126-systemd > /etc/lfs-release

cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="20171126-systemd"
DISTRIB_CODENAME="albertinos"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

logout
