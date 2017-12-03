#!/bin/bash

# USAGE EXAMPLE: ./5_build_lfs.sh

# NOTE!
# After finishing build shadow, a password is set for the
# root user. The build will halt at this time and wait for
# user input.

export MAKEFLAGS='-j 4'

source utilities.sh

# general build function for native lfs build
function package_build () {
        ./configure --prefix=/usr
        make
        make install
}

function prepare_lfs () {

	# create standard directory tree
	mkdir -p /{boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
	mkdir -p /{media/{floppy,cdrom},sbin,srv,var}
	install -d -m 0750 /root
	install -d -m 1777 /tmp /var/tmp
	mkdir -p /usr/{,local/}{bin,include,lib,sbin,src}
	mkdir -p /usr/{,local/}share/{color,dict,doc,info,locale,man}
	mkdir /usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir /usr/libexec
	mkdir -p /usr/{,local/}share/man/man{1..8}

	mkdir /var/{log,mail,spool}
	ln -s /run /var/run
	ln -s /run/lock /var/lock
	mkdir -p /var/{opt,cache,lib/{color,misc,locate},local}

	# create symlinks to our temporary tools
	ln -s /tools/bin/{cat,dd,echo,ln,pwd,rm,stty} /bin
	ln -s /tools/bin/{env,install,perl} /usr/bin
	ln -s /tools/lib/libgcc_s.so{,.1} /usr/lib
	ln -s /tools/lib/libstdc++.{a,so{,.6}} /usr/lib
	sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la
	for LIB in blkid lzma mount uuid
	do
		ln -s /tools/lib/lib${LIB}.so* /usr/lib
		sed 's/tools/usr/' /tools/lib/lib${LIB}.la > /usr/lib/lib${LIB}.la
	done
	ln -sf /tools/include/blkid    /usr/include
	ln -sf /tools/include/libmount /usr/include
	ln -sf /tools/include/uuid     /usr/include
	install -dm755 /usr/lib/pkgconfig
	for PC in blkid mount uuid
	do
	sed 's@tools@usr@g' /tools/lib/pkgconfig/${PC}.pc \
		> /usr/lib/pkgconfig/${PC}.pc
	done
	ln -s bash /bin/sh

	# finalize setup
	ln -s /proc/self/mounts /etc/mtab

	cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF



	cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
nogroup:x:99:
users:x:999:
EOF

	exec /tools/bin/bash --login +h

	touch /var/log/{btmp,lastlog,faillog,wtmp}
	chgrp -v utmp /var/log/lastlog
	chmod -v 664  /var/log/lastlog
	chmod -v 600  /var/log/btmp

}

###########################
##### BUILD FUNCTIONS #####
###########################

function build_kernel_headers () {
	package_setup "linux"

	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	find dest/include \( -name .install -o -name ..install.cmd \) -delete
	cp -r dest/include/* /usr/include

	package_teardown "linux"
}

function build_man-pages () {
	package_setup "man-pages"

	make install

	package_teardown "man-pages"
}

function build_glibc () {
	package_setup "glibc"

	patch -Np1 -i ../glibc-2.26-fhs-1.patch
	ln -sf /tools/lib/gcc /usr/lib

	GCC_INCDIR=/usr/lib/gcc/$(uname -m)-lfs-linux-gnueabihf/7.2.0/include
	ln -sf ld-linux.so.2 /lib/ld-lsb.so.3

	rm -f /usr/include/limits.h
	mkdir build
	cd build

	CC="gcc -isystem ${GCC_INCDIR} -isystem /usr/include" \
	../configure --prefix=/usr                          \
		--disable-werror                       \
		--enable-kernel=3.2                    \
		--enable-stack-protector=strong        \
		libc_cv_slibdir=/lib
	unset GCC_INCDIR
	make
	
	touch /etc/ld.so.conf
	sed '/test-installation//' -i ../Makefile
	make install

	cp ../nscd/nscd.conf /etc/nscd.conf
	mkdir -p /var/cache/nscd

	install -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
	install -Dm644 ../nscd/nscd.service /lib/systemd/system/nscd.service

	cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

	tar -xf ../../tzdata2017c.tar.gz

	ZONEINFO=/usr/share/zoneinfo
	mkdir -p ${ZONEINFO}/{posix,right}

	for TZ in etcetera southamerica northamerica europe africa antarctica  \
			asia australasia backward pacificnew systemv; do
		zic -L /dev/null   -d ${ZONEINFO}       -y "sh yearistype.sh" ${TZ}
		zic -L /dev/null   -d ${ZONEINFO}/posix -y "sh yearistype.sh" ${TZ}
		zic -L leapseconds -d ${ZONEINFO}/right -y "sh yearistype.sh" ${TZ}
	done

	cp zone.tab zone1970.tab iso3166.tab ${ZONEINFO}
	zic -d ${ZONEINFO} -p Europe/Helsinki
	unset ZONEINFO

	ln -sf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime

	cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

	mkdir -p /usr/lib/locale
	localedef -i en_US -f UTF-8 en_US.UTF-8

	package_teardown "glibc"
}

function build_zlib () {
	package_setup "zlib"

	package_build
	mv /usr/lib/libz.so.* /lib
	ln -sf /lib/libz.so /usr/lib/libz.so

	package_teardown "zlib"
}

function build_file () {
	package_setup "file"

	package_build

	package_teardown "file"
}

function build_readline () {
	package_setup "readline"

	sed -i '/MV.*old/d' Makefile.in
	sed -i '/{OLDSUFF}/c:' support/shlib-install

	./configure --prefix=/usr    \
		--disable-static \
		--docdir=/usr/share/doc/readline-7.0
	make SHLIB_LIBS="-L/tools/lib -lncursesw"
	make SHLIB_LIBS="-L/tools/lib -lncurses" install

	mv /usr/lib/lib{readline,history}.so.* /lib
	ln -sf /lib/libreadline.so /usr/lib/libreadline.so
	ln -sf /lib/libhistory.so /usr/lib/libhistory.so

	package_teardown "readline"
}

function build_m4 () {
	package_setup "m4"

	package_build

	package_teardown "m4"
}

function build_temporary_perl () {
	package_setup "perl"

	sh Configure -des -Dprefix=/tools -Dlibs=-lm
	make

	cp perl cpan/podlators/scripts/pod2man /tools/bin
	mkdir -p /tools/lib/perl5/5.26.1
	cp -R lib/* /tools/lib/perl5/5.26.1

	package_teardown "perl"
}

function build_bc () {
	package_setup "bc"

	cat > bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF

	ln -s /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
	ln -sf libncurses.so.6 /usr/lib/libncurses.so

	sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure

	./configure --prefix=/usr           \
		--with-readline         \
		--mandir=/usr/share/man \
		--infodir=/usr/share/info
	make
	make install

	package_teardown "bc"
}

function build_binutils () {
	package_setup "binutils"

	mkdir build
	cd build

	../configure --prefix=/usr       \
		--enable-gold       \
		--enable-ld=default \
		--enable-plugins    \
		--enable-shared     \
		--disable-werror    \
		--with-system-zlib  \
		--with-zlib=/usr
	make tooldir=/usr
	make tooldir=/usr install

	package_teardown "binutils"
}

function build_gmp () {
	package_setup "gmp"

	./configure --prefix=/usr    \
		--enable-cxx     \
		--disable-static \
		--docdir=/usr/share/doc/gmp-6.1.2
	make
	make install

	package_teardown "gmp"
}

function build_mpfr () {
	package_setup "mpfr"

	./configure --prefix=/usr        \
		--disable-static     \
		--enable-thread-safe \
		--with-gmp=/usr \
		--docdir=/usr/share/doc/mpfr-3.1.6
	make
	make install

	package_teardown "mpfr"
}

function build_mpc () {
	package_setup "mpc"

	./configure --prefix=/usr    \
		--disable-static \
		--with-gmp=/usr \
		--docdir=/usr/share/doc/mpc-1.0.3
	make
	make install

	package_teardown "mpc"
}

function build_gcc () {
	package_setup "gcc"

	rm -f /usr/lib/gcc
	mkdir build
	cd build

	SED=sed                               \
	../configure --prefix=/usr            \
		--enable-languages=c,c++ \
		--disable-multilib       \
		--disable-bootstrap      \
		--with-gmp=/usr          \
		--with-mpfr=/usr         \
		--with-mpc=/usr          \
		--with-system-zlib       \
		--with-zlib=/usr
	make
	make install

	ln -s ../usr/bin/cpp /lib
	ln -s gcc /usr/bin/cc

	install -dm755 /usr/lib/bfd-plugins
	ln -sf ../../libexec/gcc/$(gcc -dumpmachine)/7.2.0/liblto_plugin.so \
		/usr/lib/bfd-plugins/

	package_teardown "gcc"
}

function build_bzip2 () {
	package_setup "bzip2"

	sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
	sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
	
	make -f Makefile-libbz2_so
	make clean

	make
	make PREFIX=/usr install

	cp -v bzip2-shared /bin/bzip2
	cp -a libbz2.so* /lib
	ln -s ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
	rm /usr/bin/{bunzip2,bzcat,bzip2}
	ln -s bzip2 /bin/bunzip2
	ln -s bzip2 /bin/bzcat

	package_teardown "bzip2"
}

function build_pkg-config () {
	package_setup "pkg-config"

	./configure --prefix=/usr              \
		--with-internal-glib       \
		--disable-host-tool        \
		--docdir=/usr/share/doc/pkg-config-0.29.2
	make
	make install

	package_teardown "pkg-config"
}

function build_ncurses () {
	package_setup "ncurses"

	sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in

	./configure --prefix=/usr           \
		--mandir=/usr/share/man \
		--with-shared           \
		--without-debug         \
		--without-normal        \
		--enable-pc-files       \
		--enable-widec
	make
	make install

	mv -v /usr/lib/libncursesw.so.6* /lib
	ln -sf /lib/libncursesw.so /usr/lib/libncursesw.so

	for LIB in ncurses form panel menu ; do
    		rm -f                     /usr/lib/lib${LIB}.so
    		echo "INPUT(-l${LIB}w)" > /usr/lib/lib${LIB}.so
    		ln -sf ${LIB}w.pc         /usr/lib/pkgconfig/${LIB}.pc
	done

	package_teardown "ncurses"
}

function build_attr () {
	package_setup "attr"

	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i -e "/SUBDIRS/s|man[25]||g" man/Makefile
	sed -i 's:{(:\\{(:' test/run

	./configure --prefix=/usr \
		--disable-static
	make
	make install install-dev install-lib

	chmod -v 755 /usr/lib/libattr.so
	mv /usr/lib/libattr.so.* /lib
	ln -sf /lib/libattr.so /usr/lib/libattr.so
	ln -sf libattr.so.1 /lib/libattr.so

	package_teardown "attr"
}

function build_acl () {
	package_setup "acl"

	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i -e "/TABS-1;/a if (x > (TABS-1)) x = (TABS-1);" \
		libacl/__acl_to_any_text.c

	./configure --prefix=/usr    \
		--disable-static \
		--libexecdir=/usr/lib
	make
	make install install-dev install-lib

	chmod -v 755 /usr/lib/libacl.so
	mv /usr/lib/libacl.so.* /lib
	ln -sf /lib/libacl.so /usr/lib/libacl.so

	package_teardown "acl"
}

function build_libcap () {
	package_setup "libcap"

	sed -i '/install.*STALIBNAME/d' libcap/Makefile

	make
	make RAISE_SETFCAP=no lib=lib prefix=/usr install
	
	chmod -v 755 /usr/lib/libcap.so
	mv /usr/lib/libcap.so.* /lib
	ln -sf /lib/libcap.so /usr/lib/libcap.so
	ln -sf libcap.so.2 /lib/libcap.so

	package_teardown "libcap"
}

function build_sed () {
	package_setup "sed"

	./configure --prefix=/usr --bindir=/bin
	make
	make install

	package_teardown "sed"
}

function build_shadow () {
	package_setup "shadow"

	sed -i 's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
	find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
	find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

	sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
		-e 's@/var/spool/mail@/var/mail@' etc/login.defs
	sed -i 's/1000/999/' etc/useradd

	./configure --sysconfdir=/etc --with-group-name-max-length=32
	make
	make install

	mv -v /usr/bin/passwd /bin

	pwconv
	grpconv

	sed -i 's/yes/no/' /etc/default/useradd
	passwd root

	package_teardown "shadow"
}

function build_psmisc () {
	package_setup "psmisc"

	package_build
	mv -v /usr/bin/fuser   /bin
	mv -v /usr/bin/killall /bin

	package_teardown "psmisc"
}

function build_iana-etc () {
	package_setup "iana-etc"

	make
	make install

	package_teardown "iana-etc"
}

function build_bison () {
	package_setup "bison"

	./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.4
	make
	make install

	package_teardown "bison"
}

function build_flex () {
	package_setup "flex"

	sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
	
	HELP2MAN=/tools/bin/true \
	./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
	make
	make install

	ln -s flex /usr/bin/lex

	package_teardown "flex"
}

function build_grep () {
	package_setup "grep"

	./configure --prefix=/usr --bindir=/bin
	make
	make install

	package_teardown "grep"
}

function build_bash () {
	package_setup "bash"

	./configure --prefix=/usr                       \
		--docdir=/usr/share/doc/bash-4.4.12 \
		--without-bash-malloc               \
		--with-installed-readline
	make
	make install

	mv -f /usr/bin/bash /bin
	exec /bin/bash --login +h

	package_teardown "bash"
}

function build_libtool () {
	package_setup "libtool"

	package_build

	package_teardown "libtool"
}

function build_gdbm () {
	package_setup "gdbm"

	./configure --prefix=/usr \
		--disable-static \
		--enable-libgdbm-compat
	make
	make install

	package_teardown "gdbm"
}

function build_gperf () {
	package_setup "gperf"

	./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
	make
	make install

	package_teardown "gperf"
}

function build_expat () {
	package_setup "expat"

	./configure --prefix=/usr --disable-static
	make
	make install

	package_teardown "expat"
}

function build_inetutils () {
	package_setup "inetutils"

	./configure --prefix=/usr        \
		--localstatedir=/var \
		--disable-logger     \
		--disable-whois      \
		--disable-rcp        \
		--disable-rexec      \
		--disable-rlogin     \
		--disable-rsh        \
		--disable-servers
	make
	make install

	mv /usr/bin/{hostname,ping,ping6,traceroute} /bin
	mv /usr/bin/ifconfig /sbin

	package_teardown "inetutils"
}

function build_perl () {
	package_setup "perl"

	export BUILD_ZLIB=False
	export BUILD_BZIP2=0

	sh Configure -des -Dprefix=/usr                 \
		-Dvendorprefix=/usr           \
		-Dman1dir=/usr/share/man/man1 \
		-Dman3dir=/usr/share/man/man3 \
		-Dpager="/usr/bin/less -isR"  \
		-Duseshrplib                  \
		-Dusethreads
	make
	make install

	unset BUILD_ZLIB BUILD_BZIP2

	package_teardown "perl"
}

function build_XML-Parser () {
	package_setup "XML-Parser"

	perl Makefile.PL
	make
	make install

	package_teardown "XML-Parser"
}

function build_intltool () {
	package_setup "intltool"

	sed -i 's:\\\${:\\\$\\{:' intltool-update.in
	package_build

	package_teardown "intltool"
}

function build_autoconf () {
	package_setup "autoconf"

	package_build

	package_teardown "autoconf"
}

function build_automake () {
	package_setup "automake"

	./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.15.1
	make
	make install

	package_teardown "automake"
}

function build_xz () {
	package_setup "xz"

	./configure --prefix=/usr    \
		--disable-static \
		--docdir=/usr/share/doc/xz-5.2.3
	make
	make install

	mv /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
	mv /usr/lib/liblzma.so.* /lib
	ln -sf /lib/liblzma.so /usr/lib/liblzma.so
	ln -sf liblzma.so.5 /lib/liblzma.so

	package_teardown "xz"
}

function build_kmod () {
	package_setup "kmod"

	./configure --prefix=/usr          \
		--bindir=/bin          \
		--sysconfdir=/etc      \
		--with-rootlibdir=/lib \
		--with-xz              \
		--with-zlib
	make
	make install

	
	for TARGET in depmod insmod lsmod modinfo modprobe rmmod; do
		ln -sf ../bin/kmod /sbin/$TARGET
	done
	ln -sf kmod /bin/lsmod

	package_teardown "kmod"
}

function build_gettext () {
	package_setup "gettext"

	./configure --prefix=/usr    \
		--disable-static \
		--docdir=/usr/share/doc/gettext-0.19.8.1
	make
	make install

	chmod -v 0755 /usr/lib/preloadable_libintl.so

	package_teardown "gettext"
}

function build_libffi () {
	package_setup "libffi"

	sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
		-i include/Makefile.in
	sed -e '/^includedir/ s/=.*$/=@includedir@/' \
		-e 's/^Cflags: -I${includedir}/Cflags:/' \
		-i libffi.pc.in

	./configure --prefix=/usr --disable-static
	make
	make install

	package_teardown "libffi"
}

function build_Python () {
	package_setup "Python"

	./configure --prefix=/usr       \
		--enable-shared     \
		--with-system-expat \
		--with-system-ffi   \
		--with-ensurepip=yes
	make
	make install

	chmod -v 755 /usr/lib/libpython3.6m.so
	chmod -v 755 /usr/lib/libpython3.so

	package_teardown "Python"
}

function build_ninja () {
	package_setup "ninja"

	python3 configure.py --bootstrap
	install -m755 ninja /usr/bin/
	install -Dm644 misc/ninja.vim       /usr/share/vim/vim80/syntax/ninja.vim
	install -Dm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
	install -Dm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

	package_teardown "ninja"
}

function build_meson () {
	package_setup "meson"

	python3 setup.py build
	python3 setup.py install

	package_teardown "meson"
}

function build_systemd () {
	package_setup "systemd"

	ln -s /tools/bin/true /usr/bin/xsltproc
	tar -xf ../systemd-man-pages-235.tar.xz

	mkdir build
	cd build

	LANG=en_US.UTF-8                   \
	meson --prefix=/usr                \
		--sysconfdir=/etc            \
		--localstatedir=/var         \
		-Dblkid=true                 \
		-Dbuildtype=release          \
		-Ddefault-dnssec=no          \
		-Dfirstboot=false            \
		-Dkill-path=/bin/kill        \
		-Dkmod-path=/bin/kmod        \
		-Dldconfig=false             \
		-Dmount-path=/bin/mount      \
		-Drootprefix=                \
		-Drootlibdir=/lib            \
		-Dsplit-usr=true             \
		-Dsulogin-path=/sbin/sulogin \
		-Dsysusers=false             \
		-Dumount-path=/bin/umount    \
		-Db_lto=false                \
		..
	LANG=en_US.UTF-8 ninja
	LANG=en_US.UTF-8 ninja install

	rm -rf /usr/lib/rpm
	
	for TOOL in runlevel reboot shutdown poweroff halt telinit; do
		ln -sfv ../bin/systemctl /sbin/${TOOL}
	done
	ln -sf ../lib/systemd/systemd /sbin/init

	rm -f /usr/bin/xsltproc
	systemd-machine-id-setup

	cat > /lib/systemd/systemd-user-sessions << "EOF"
#!/bin/bash
rm -f /run/nologin
EOF
	chmod 755 /lib/systemd/systemd-user-sessions

	package_teardown "systemd"
}

function build_procps-ng () {
	package_setup "procps-ng"

	./configure --prefix=/usr                            \
		--exec-prefix=                           \
		--libdir=/usr/lib                        \
		--docdir=/usr/share/doc/procps-ng-3.3.12 \
		--disable-static                         \
		--disable-kill                           \
		--with-systemd
	make
	make install

	mv /usr/lib/libprocps.so.* /lib
	ln -sf /lib/libprocps.so /usr/lib/libprocps.so

	package_teardown "procps-ng"
}

function build_e2fsprogs () {
	package_setup "e2fsprogs"

	mkdir build
	cd build

	LIBS=-L/tools/lib                    \
	CFLAGS=-I/tools/include              \
	PKG_CONFIG_PATH=/tools/lib/pkgconfig \
	../configure --prefix=/usr           \
		--bindir=/bin           \
		--with-root-prefix=""   \
		--enable-elf-shlibs     \
		--disable-libblkid      \
		--disable-libuuid       \
		--disable-uuidd         \
		--disable-fsck
	make
	make install
	make install-libs

	chmod u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
	gunzip -v /usr/share/info/libext2fs.info.gz
	install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

	package_teardown "e2fsprogs"
}

function build_coreutils () {
	package_setup "coreutils"

	patch -Np1 -i ../coreutils-8.28-i18n-1.patch

	FORCE_UNSAFE_CONFIGURE=1 ./configure \
		--prefix=/usr            \
		--enable-no-install-program=kill,uptime
	FORCE_UNSAFE_CONFIGURE=1 make
	make install

	mv /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin/
	mv /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin/
	mv /usr/bin/{rmdir,stty,sync,true,uname} /bin/
	mv /usr/bin/chroot /usr/sbin/
	mv /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
	sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
	mv /usr/bin/{head,sleep,nice} /bin

	package_teardown "coreutils"
}

function build_diffutils () {
	package_setup "diffutils"

	package_build

	package_teardown "diffutils"
}

function build_gawk () {
	package_setup "gawk"

	sed -i 's/extras//' Makefile.in
	package_build

	package_teardown "gawk"
}

function build_findutils () {
	package_setup "findutils"

	./configure --prefix=/usr --localstatedir=/var/lib/locate
	make
	make install

	mv /usr/bin/find /bin
	sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

	package_teardown "findutils"
}

function build_groff () {
	package_setup "groff"

	PAGE=A4 ./configure --prefix=/usr
	make -j1
	make install

	package_teardown "groff"
}

function build_less () {
	package_setup "less"

	./configure --prefix=/usr --sysconfdir=/etc
	make
	make install

	package_teardown "less"
}

function build_gzip () {
	package_setup "gzip"

	package_build
	mv -v /usr/bin/gzip /bin

	package_teardown "gzip"
}

function build_iproute () {
	package_setup "iproute"

	sed -i /ARPD/d Makefile
	rm -f man/man8/arpd.8
	sed -i 's/m_ipt.o//' tc/Makefile

	make
	make DOCDIR=/usr/share/doc/iproute2-4.14.1 install

	package_teardown "iproute"
}

function build_kbd () {
	package_setup "kbd"

	patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
	sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
	sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

	PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
	make
	make install

	package_teardown "kbd"
}

function build_libpipeline () {
	package_setup "libpipeline"

	PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr
	make
	make install

	package_teardown "libpipeline"
}

function build_make () {
	package_setup "make"

	package_build

	package_teardown "make"
}

function build_patch () {
	package_setup "patch"

	package_build

	package_teardown "patch"
}

function build_dbus () {
	package_setup "dbus"

	./configure --prefix=/usr                       \
		--sysconfdir=/etc                   \
		--localstatedir=/var                \
		--disable-static                    \
		--disable-doxygen-docs              \
		--disable-xml-docs                  \
		--docdir=/usr/share/doc/dbus-1.12.2 \
		--with-console-auth-dir=/run/console
	make
	make install

	mv /usr/lib/libdbus-1.so.* /lib
	ln -sf /lib/libdbus-1.so /usr/lib/libdbus-1.so
	ln -sf /etc/machine-id /var/lib/dbus

	package_teardown "dbus"
}

function build_util-linux () {
	package_setup "util-linux"

	mkdir -p /var/lib/hwclock
	rm -f /usr/include/{blkid,libmount,uuid}

	./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
		--docdir=/usr/share/doc/util-linux-2.31 \
		--disable-chfn-chsh  \
		--disable-login      \
		--disable-nologin    \
		--disable-su         \
		--disable-setpriv    \
		--disable-runuser    \
		--disable-pylibmount \
		--disable-static     \
		--without-python
	make
	make install

	package_teardown "util-linux"
}

function build_man-db () {
	package_setup "man-db"

	./configure --prefix=/usr                        \
		--docdir=/usr/share/doc/man-db-2.7.6.1 \
		--sysconfdir=/etc                    \
		--disable-setuid                     \
		--enable-cache-owner=bin             \
		--with-browser=/usr/bin/lynx         \
		--with-vgrind=/usr/bin/vgrind        \
		--with-grap=/usr/bin/grap
	make
	make install

	sed -i "s:man man:root root:g" /usr/lib/tmpfiles.d/man-db.conf

	package_teardown "man-db"
}

function build_tar () {
	package_setup "tar"

	FORCE_UNSAFE_CONFIGURE=1  \
	./configure --prefix=/usr \
		--bindir=/bin
	make
	make install

	package_teardown "tar"
}

function build_texinfo () {
	package_setup "texinfo"

	./configure --prefix=/usr --disable-static
	make
	make install

	package_teardown "texinfo"
}

function build_vim () {
	tar xf vim-8.0.586.tar.bz2
	cd vim80

	echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
	
	package_build

	ln -sv vim /usr/bin/vi
	for L in  /usr/share/man/{,*/}man1/vim.1; do
		ln -sv vim.1 $(dirname ${L})/vi.1
	done

	ln -sv ../vim/vim80/doc /usr/share/doc/vim-8.0.586

	cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

set nocompatible
set backspace=2
set mouse=r
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif


" End /etc/vimrc
EOF
	touch ~/.vimrc

	cd ..
	rm -rf vim80
}

function build_kernel () {
	package_setup "linux"

	KERNEL=kernel7
	make bcm2835_defconfig

	make -j4 zImage modules dtbs
	make modules_install

	cp arch/arm/boot/dts/*.dtb /boot/
	cp arch/arm/boot/zImage /boot/$KERNEL.img
	cp System.map /boot/System.map-4.14
	cp .config /boot/config-4.14

	package_teardown "linux"
}

#######################
##### START BUILD #####
#######################

prepare_lfs

cd /sources

build_kernel_headers
build_man-pages
build_glibc

# adjust toolchain to use new c libraries
mv /tools/bin/{ld,ld-old}
mv /tools/$(uname -m)-lfs-linux-gnueabihf/bin/{ld,ld-old}
mv /tools/bin/{ld-new,ld}
ln -s /tools/bin/ld /tools/$(uname -m)-lfs-linux-gnueabihf/bin/ld

gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

build_zlib
build_file
build_readline
build_m4
build_temporary_perl
build_bc
build_binutils
build_gmp
build_mpfr
build_mpc
build_gcc
build_bzip2
build_pkg-config
build_ncurses
build_attr
build_acl
build_libcap
build_sed
build_shadow
build_psmisc
build_iana-etc
build_bison
build_flex
build_grep
build_bash
build_libtool
build_gdbm
build_gperf
build_expat
build_inetutils
build_perl
build_XML-Parser
build_intltool
build_autoconf
build_automake
build_xz
build_kmod
build_gettext
build_libffi
build_Python
build_ninja
build_meson
build_systemd
build_procps-ng
build_e2fsprogs
build_coreutils
build_diffutils
build_gawk
build_findutils
build_groff
build_less
build_gzip
build_iproute
build_kbd
build_libpipeline
build_make
build_patch
build_dbus
build_util-linux
build_man-db
build_tar
build_texinfo
build_vim
build_kernel

rm -rf /tmp/*
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a

cd ..

rm -rf sources
rm -rf tools

/bin/cp 6_configure_lfs ${LFS}

