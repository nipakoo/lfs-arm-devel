#!/bin/bash

# USAGE EXAMPLE: ./3_build_tools.sh

cp wget-list ${LFS}
source utilities.sh

# create dir for installing the tools in
mkdir ${LFS}/tools
ln -s ${LFS}/tools /

# general build function for toolset
function package_build () {
        ./configure --prefix=/tools
        make
        make install
}

###########################
##### BUILD FUNCTIONS #####
###########################

function build_cross_binutils () {
	package_setup "binutils"

	mkdir build
	cd build

	../configure --prefix=/tools		\
		--with-sysroot=${LFS}		\
		--with-lib-path=/tools/lib	\
		--target=${LFS_TGT}		\
		--disable-nls			\
		--disable-werror
	make
	make install

	package_teardown "binutils"
}

function build_cross_gcc () {
	package_setup "gcc"

	for PKG in mpfr gmp mpc; do
		TARBALL=$(parse_tarball ${PKG})
		SRCDIR=$(parse_srcdir ${TARBALL})
		tar xf ../${TARBALL}
		mv ${SRCDIR} ${PKG}
	done

	for FILE in gcc/config/arm/linux-eabi.h; do
		cp -uv ${FILE}{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' ${FILE}.orig > ${FILE}
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> ${FILE}
		touch ${FILE}.orig
	done

	mkdir build
	cd build

	../configure                                           \
		--target=${LFS_TGT}                            \
		--prefix=/tools                                \
		--with-glibc-version=2.11                      \
		--with-sysroot=${LFS}                          \
		--with-newlib                                  \
		--without-headers                              \
		--with-local-prefix=/tools                     \
		--with-native-system-header-dir=/tools/include \
		--disable-nls                                  \
		--disable-shared                               \
		--disable-multilib                             \
		--disable-decimal-float                        \
		--disable-threads                              \
		--disable-libatomic                            \
		--disable-libgomp                              \
		--disable-libmpx                               \
		--disable-libquadmath                          \
		--disable-libssp                               \
		--disable-libvtv                               \
		--disable-libstdcxx                            \
		--enable-languages=c,c++
	make
	make install

	package_teardown "gcc"
}

function build_kernel_headers () {
	package_setup "linux"

	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	cp -r dest/include/* /tools/include

	package_teardown "linux"
}

function build_glibc () {
	package_setup "glibc"

	mkdir build
	cd build

	../configure                               \
		--prefix=/tools                    \
		--host=${LFS_TGT}                  \
		--build=$(../scripts/config.guess) \
		--enable-kernel=3.2                \
		--with-headers=/tools/include      \
		libc_cv_forced_unwind=yes          \
		libc_cv_c_cleanup=yes
	make
	make install

	package_teardown "glibc"
}

function build_libstcpp () {
	package_setup "gcc"

	mkdir build
	cd build

	../libstdc++-v3/configure               \
		--host=${LFS_TGT}               \
		--prefix=/tools                 \
		--disable-multilib              \
		--disable-nls                   \
		--disable-libstdcxx-threads     \
		--disable-libstdcxx-pch         \
		--with-gxx-include-dir=/tools/${LFS_TGT}/include/c++/7.2.0
	make
	make install

	package_teardown "gcc"
}

function build_binutils () {
	package_setup "binutils"

	mkdir build
	cd build

	CC=${LFS_TGT}-gcc                  \
	AR=${LFS_TGT}-ar                   \
	RANLIB=${LFS_TGT}-ranlib           \
	../configure                       \
		--prefix=/tools            \
		--disable-nls              \
		--disable-werror           \
		--with-lib-path=/tools/lib \
		--with-sysroot
	make
	make install

	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib
	cp ld/ld-new /tools/bin

	package_teardown "binutils"
}

function build_gcc () {
	package_setup "gcc"

	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		`dirname $(${LFS_TGT}-gcc -print-libgcc-file-name)`/include-fixed/limits.h

	for FILE in gcc/config/arm/linux-eabi.h; do
		cp -uv ${FILE}{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' ${FILE}.orig > ${FILE}
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> ${FILE}
		touch ${FILE}.orig
	done

	for PKG in mpfr gmp mpc; do
                TARBALL=$(parse_tarball ${PKG})
		SRCDIR=$(parse_srcdir ${TARBALL})
                tar xf ../${TARBALL}
		mv ${SRCDIR} ${PKG}
        done

	mkdir build
	cd build

	CC=${LFS_TGT}-gcc                                      \
	CXX=${LFS_TGT}-g++                                     \
	AR=${LFS_TGT}-ar                                       \
	RANLIB=${LFS_TGT}-ranlib                               \
	../configure                                           \
		--prefix=/tools                                \
		--with-local-prefix=/tools                     \
		--with-native-system-header-dir=/tools/include \
		--enable-languages=c,c++                       \
		--disable-libstdcxx-pch                        \
		--disable-multilib                             \
		--disable-bootstrap                            \
		--disable-libgomp
	make
	make install

	ln -s gcc /tools/bin/cc

	package_teardown "gcc"
}

function build_ncurses () {
	package_setup "ncurses"

	sed -i s/mawk// configure
	./configure --prefix=/tools \
		--with-shared   \
		--without-debug \
		--without-ada   \
		--enable-widec  \
		--enable-overwrite
	make
	make install

	package_teardown "ncurses"
}

function build_bash () {
	package_setup "bash"

	patch builtins/psize.sh < ${LFS}/sources/hardcode-PIPESIZE.patch

	./configure --prefix=/tools --without-bash-malloc
	make
	make install

	ln -s bash /tools/bin/sh

#	package_teardown "bash"
}

function build_bison () {
	package_setup "bison"

	package_build

	package_teardown "bison"
}

function build_bzip2 () {
	package_setup "bzip2"

	make
	make PREFIX=/tools install

	package_teardown "bzip2"
}

function build_coreutils () {
	package_setup "coreutils"

	./configure --prefix=/tools --enable-install-program=hostname
	make
	make install

	package_teardown "coreutils"
}

function build_diffutils () {
	package_setup "diffutils"

	package_build

	package_teardown "diffutils"
}

function build_file () {
	package_setup "file"

	package_build

	package_teardown "file"
}

function build_findutils () {
	package_setup "findutils"

	package_build

	package_teardown "findutils"
}

function build_gawk () {
	package_setup "gawk"

	package_build

	package_teardown "gawk"
}

function build_gettext () {
	package_setup "gettext"

	cd gettext-tools
	
	EMACS="no" ./configure --prefix=/tools --disable-shared
	make -C gnulib-lib
	make -C intl pluralx.c
	make -C src msgfmt
	make -C src msgmerge
	make -C src xgettext

	cp src/{msgfmt,msgmerge,xgettext} /tools/bin

	package_teardown "gettext"
}

function build_grep () {
	package_setup "grep"

	package_build

	package_teardown "grep"
}

function build_gzip () {
	package_setup "gzip"

	package_build

	package_teardown "gzip"
}

function build_m4 () {
	package_setup "m4"

	package_build

	package_teardown "m4"
}

function build_make () {
	package_setup "make"

	./configure --prefix=/tools --without-guile
	make
	make install

	package_teardown "make"
}

function build_patch () {
	package_setup "patch"

	package_build

	package_teardown "patch"
}

function build_sed () {
	package_setup "sed"

	package_build

	package_teardown "sed"
}

function build_tar () {
	package_setup "tar"

	package_build

	package_teardown "tar"
}

function build_texinfo () {
	package_setup "texinfo"

	package_build

	package_teardown "texinfo"
}

function build_util-linux () {
	package_setup "util-linux"

	./configure --prefix=/tools            \
		--without-python               \
		--disable-makeinstall-chown    \
		--without-systemdsystemunitdir \
		--without-ncurses              \
		PKG_CONFIG=""
	make
	make install

	package_teardown "util-linux"
}

function build_xz () {
	package_setup "xz"

	package_build

	package_teardown "xz"
}



#######################
##### START BUILD #####
#######################

pushd ${LFS}/sources > /dev/null

build_cross_binutils
build_cross_gcc
build_kernel_headers
build_glibc
build_libstcpp
build_binutils
build_gcc
build_ncurses
build_bash
build_bison
build_bzip2
build_coreutils
build_diffutils
build_file
build_findutils
build_gawk
build_gettext
build_grep
build_gzip
build_m4
build_make
build_patch
build_sed
build_tar
build_texinfo
build_util-linux
build_xz

popd > /dev/null

# strip away debug symbols and docs
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}

