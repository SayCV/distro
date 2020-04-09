#!/bin/bash

set -e
DISTRO_DIR=$(cd "$(dirname "$0")"; pwd)
TOP_DIR=$DISTRO_DIR/..

# source $TOP_DIR/device/sunxi/.BoardConfig.mk
# Target arch
export RK_ARCH=arm
# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=ext4

source $DISTRO_DIR/envsetup.sh
source $OUTPUT_DIR/.config
DISTRO_CONFIG=$OUTPUT_DIR/.config
ROOTFS_DEBUG_EXT4=$IMAGE_DIR/rootfs.debug.ext4
ROOTFS_DEBUG_SQUASHFS=$IMAGE_DIR/rootfs.debug.squashfs
ROOTFS_EXT4=$IMAGE_DIR/rootfs.ext4
ROOTFS_SQUASHFS=$IMAGE_DIR/rootfs.squashfs
BUILD_PACKAGE=$1
export SUITE=xenial
export ARCH=$RK_ARCH

OS=`$SCRIPTS_DIR/get_distro.sh $SUITE`

log() {
    local format="$1"
    shift
    printf -- "$format\n" "$@" >&2
}

die() {
    local format="$1"
    shift
    log "E: $format" "$@"
    exit 1
}

run() {
    log "I: Running command: %s" "$*"
    "$@"
}

clean()
{
	rm -rf $OUTPUT_DIR
}

pack_squashfs()
{
	SRC=$1
	DST=$2
	mksquashfs $SRC $DST -noappend -comp gzip
}

pack_ext4()
{
	SRC=$1
	DST=$2
	SIZE=`du -sk --apparent-size $SRC | cut --fields=1`
	inode_ratio=4096
	inode_counti=`find $SRC | wc -l`
	inode_counti=$[inode_counti+512]
	EXTRA_SIZE=$[inode_counti*4]
	SIZE=$[SIZE+EXTRA_SIZE]
	if [ $SIZE -lt $[4*1024*1024] ];then
		SIZE=$[4*1024*1024]
	fi
	inode_counti=$[4*1024*1024*1024/inode_ratio]
	run genext2fs -U -b $SIZE -N $inode_counti -d $SRC $DST
	run tune2fs -O dir_index,filetype $DST
	run e2fsck -fy $DST $> /dev/null || e2fsck $DST
#	if [ -x $DISTRO_DIR/../device/rockchip/common/mke2img.sh ];then
#		$DISTRO_DIR/../device/rockchip/common/mke2img.sh $SRC $DST
#	fi
}

pack()
{
	echo "packing rootfs image..."
	if [ $RK_ROOTFS_TYPE = ext4 ];then
		pack_ext4 $TARGET_DIR $ROOTFS_EXT4
	elif [ $RK_ROOTFS_TYPE = squashfs ];then
		pack_squashfs $ROOTFS_DIR $ROOTFS_SQUASHFS
	fi
}

build_packages()
{
	for p in $(ls $DISTRO_DIR/package/);do
		[ -d $DISTRO_DIR/package/$p ] || continue
		local config=BR2_PACKAGE_$(echo $p|tr 'a-z-' 'A-Z_')
		local build=$(eval echo -n \$$config)
		#echo "Build $pkg($config)? ${build:-n}"
		[ x$build == xy ] && $SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE $p
	done
	echo "finish building all packages"
}

install_deb_dependies()
{
	local install_pkgs

	for p in $(ls $DISTRO_DIR/package/); do
		[ -f $DISTRO_DIR/package/$p/make.sh ] || continue
		dependencies=`grep DEPENDENCIES= $DISTRO_DIR/package/$p/make.sh| head -1 | cut -d '=' -f 2 | tr -d '"'`
		install_pkgs+=' '$dependencies
	done

	for p in $(ls $DISTRO_DIR/package/); do
		[ -f $DISTRO_DIR/package/$p/make.sh ] || continue

		# ${str/substr/} can't handle this scenario:
		# pkg: gstreamer gstreamer-rockchip
		# without -->p=' '$p' ', the output will be -rockchip.
		p=' '$p' '
		install_pkgs=${install_pkgs//$p/' '}
	done
	echo "dependencies package are:"$install_pkgs
	$SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE "$install_pkgs"
}

install_lib_moudles()
{
	local KERNEL_VERSION="3.10.65"
	fakeroot mkdir -p $DISTRO_DIR/output/target/lib/modules/
	fakeroot cp -rf $TOP_DIR/linux-3.10/output/lib/modules/${KERNEL_VERSION} $DISTRO_DIR/output/target/lib/modules/
	fakeroot cp -rf $TOP_DIR/libdaq19/install/lib/modules/*.ko $DISTRO_DIR/output/target/lib/modules/${KERNEL_VERSION}/
}

init()
{
	mkdir -p $OUTPUT_DIR $BUILD_DIR $TARGET_DIR $IMAGE_DIR $MOUNT_DIR $SYSROOT_DIR $CACHE_DIR
	mkdir -p $TARGET_DIR/etc/apt/sources.list.d $TARGET_DIR/var/cache/apt/archives

	if [ -z $ARCH ];then
		export ARCH=arm64
	fi

	while read line1; do INSTALL_PKG="$INSTALL_PKG $line1"; done < "$OUTPUT_DIR/.install"
}

build_base()
{
	$SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE "$INSTALL_PKG" "init"
}

build_all()
{
	init $1
	build_base
#	install_deb_dependies
	build_packages
	install_lib_moudles
	$SCRIPTS_DIR/override_deb.sh
	run rsync -a --ignore-times --keep-dirlinks --chmod=u=rwX,go=rX --exclude .empty $OVERLAY_DIR/ $TARGET_DIR/
	run rsync -a --ignore-times --keep-dirlinks --chmod=u=rwX,go=rX --exclude .empty $OVERLAY_DIR2/ $TARGET_DIR/
	pack
}

main()
{
	if [ x$1 == ximage ];then
		init
		pack
		exit 0
	elif [ x$1 == xbase ];then
		init
		build_base
		exit 0
	elif [ x$1 == xmirror ] && [ -n $2 ];then
		echo $2 > $OUTPUT_DIR/.mirror
		exit 0
	elif [ -z $1 ];then
		build_all
		exit 0
	else
		init
		p=$1
		if [ x"-rebuild" == x`echo ${p:0-8:8}` ];then
			p=`echo ${p%%-*}`
			rm -rf $BUILD_DIR/$p
		fi
		$SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE $p
		exit 0
	fi
}

main "$@"
