#!/bin/bash

function parse_tarball () {
        PKG_NAME=$1
        TARBALL=$(cat ${LFS}/wget-list | rev | cut -d '/' -f 1 | rev | grep ${PKG_NAME}- | head -n 1)
	if [[ -z $TARBALL ]]; then
		echo $(cat ${LFS}/wget-list | rev | cut -d '/' -f 1 | rev | grep ${PKG_NAME} | head -n 1)
		return
	fi
	echo $TARBALL
}

function parse_srcdir () {
        TARBALL=$1
        if [[ $(echo ${TARBALL} |grep .src.tar.gz) ]]; then
                echo ${TARBALL%.src.tar.gz}
                return
        fi
        if [[ $(echo ${TARBALL} |grep \\-src.tar.gz) ]]; then
                echo ${TARBALL%-src.tar.gz}
                return
        fi
        if [[ $(echo ${TARBALL} |grep .tar.gz) ]]; then
                echo ${TARBALL%.tar.gz}
                return
        fi
        if [[ $(echo ${TARBALL} |grep .tar.xz) ]]; then
                echo ${TARBALL%.tar.xz}
                return
        fi
        if [[ $(echo ${TARBALL} |grep .tar.bz2) ]]; then
                echo ${TARBALL%.tar.bz2}
                return
        fi
}

function package_setup () {
        PKG_NAME=$1
        TARBALL=$(parse_tarball ${PKG_NAME})
        SRCDIR=$(parse_srcdir ${TARBALL})
        tar xf ${TARBALL}
        cd ${SRCDIR}
}

function package_teardown () {
        cd ${LFS}/sources
        PKG_NAME=$1
        SRCDIR=$(ls |grep ${PKG_NAME} |head -n 1)
        rm -rf ${SRCDIR}
}

