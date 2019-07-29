#!/bin/bash

set -e
PKG=gallery
DEPENDENCIES="weston libqt5widgets5 libatomic1 qtwayland5"
$SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE "$DEPENDENCIES"
#QMAKE=/usr/bin/qmake
QMAKE=$TOP_DIR/buildroot/output/$RK_CFG_BUILDROOT/host/bin/qmake
mkdir -p $BUILD_DIR/$PKG
cd $BUILD_DIR/$PKG
$QMAKE $TOP_DIR/app/$PKG
make -j$RK_JOBS
mkdir -p $TARGET_DIR/usr/share/icon
cp $TOP_DIR/app/$PKG/conf/icon_gallery.png $TARGET_DIR/usr/share/icon/
mkdir -p $TARGET_DIR/usr/share/applications
install -m 0644 -D $TOP_DIR/app/$PKG/gallery.desktop $TARGET_DIR/usr/share/applications/
install -m 0755 -D $BUILD_DIR/$PKG/galleryView $TARGET_DIR/usr/bin/galleryView
cd -

