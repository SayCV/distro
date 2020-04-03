#!/bin/bash

set -e
DEPENDENCIES="android-tools-adbd parted gdisk"
$SCRIPTS_DIR/build_pkgs.sh $ARCH $SUITE "$DEPENDENCIES"

sudo chroot ${TARGET_DIR} ln -sf /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@ttyS0.service
