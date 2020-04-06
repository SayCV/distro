#!/bin/bash
set -e

CMD=`realpath $0`
SCRIPT_DIR=`dirname $CMD`
dl_dir=$(realpath $SCRIPT_DIR/../download)

echo "top:$TOP_DIR"
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters. Needs two parameters: arch (i.e. arm or arm64) and name of director"
    exit 1
fi

arch=$1
suite=$2
dir=$3

if [ x$suite == xxenial ]; then
	version_minor=16.04.4
	version_major=16.04
elif [ x$suite == xbionic ]; then
	version_minor=18.04.4
	version_major=18.04
else
	echo "wrong suite parameter, check it again"
fi

if [ x$arch == xarm64 ]; then
	name=ubuntu-base-${version_minor}-base-arm64.tar.gz
	qemu_arch=aarch64
elif [ x$arch == xarm ]; then
	name=ubuntu-base-${version_minor}-base-armhf.tar.gz
	qemu_arch=arm
else
	echo "wrong arch parameter, it should be arm or arm64"
fi

qemu=qemu-$qemu_arch-static
# https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/
# url=http://cdimage.ubuntu.com/ubuntu-base/releases/${version_major}/release/${name}
url=http://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${version_major}/release/${name}


if [ ! -e ${dl_dir}/${name} ];then 
	wget -P ${dl_dir} -c ${url}
else
	fakeroot tar -xf ${dl_dir}/${name} -C ${dir}/
fi

fakeroot cp /usr/bin/${qemu} ${dir}/usr/bin/
#fakeroot sed -i 's%^# deb %deb %' ${dir}/etc/apt/sources.list
# overwrite apt source list
fakeroot cp -rf $TOP_DIR/distro/overlay/etc/apt/sources.${version_major}.list ${dir}/etc/apt/sources.list

fakeroot cp /etc/resolv.conf ${dir}/etc/resolv.conf


