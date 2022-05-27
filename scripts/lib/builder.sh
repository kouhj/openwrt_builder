#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
#      This file contains the common routines used by the image builer.
# Lisence: MIT
# Author: kouhj
#========================================================================================

# Conditional sourcing avoid sourcing twice
if ! LC_ALL=C type -t _set_env >/dev/null; then
  source "${BUILDER_WORK_DIR}/scripts/lib/gaction.sh"
fi

# Add package feed to repo with name $1 and URL $2
add_feed_to_repositories_conf() {
	if ! grep -q $1 repositories.conf; then
		echo "src/gz $1 $2" >> repositories.conf
	fi
}

# Add package feed to repo with type $1 name $2 and URL $3
add_feed_to_feeds_conf() {
	if ! grep -q $2 feeds.conf; then
		echo "$1 $2 $3" >> feeds.conf
	fi
}

config_option_select() {
	[[ "$2" == 'y' || "$2" == 'yes' ]] && (
		sed -i -r "s/^# ($1) is not set/\1=y/" .config
	) || (
		sed -i -r "s/^($1)=y/\# \1 is not set/" .config
	)
	grep $1 .config
}

config_option_set() {
	sed -i -r "s~^.*($1)[= ].*\$~\1=$2~" .config
	grep $1 .config
}

get_config_option() {
  local v=$(sed -n -r 's/'$1'="(.*)"/\1/p' .config)
  eval "$1=$v"
  _set_env $1
  _docker_set_env $1
}

config_openwrt_sdk() {
	local PKGS_SRC_TOP="$OPENWRT_CUR_DIR/package"
	local PKGS_DST_TOP="$OPENWRT_SDK_DIR/package"
	pushd $PKGS_DST_TOP
	
	mkdir -p feeds feeds/luci kernel libs utils
	
	# Extra package dependencies for ksoftethervpn
	for lib in zlib libiconv ncurses openssl readline; do
		[ -h $PKGS_DST_TOP/libs/$lib ] || ln -sf $PKGS_SRC_TOP/libs/$lib $PKGS_DST_TOP/libs/
	done
	for pkg in feeds/kouhj feeds/luci/luci-base kernel/cryptodev-linux utils/lua; do
		[ -h $PKGS_DST_TOP/$pkg ] || ln -sf $PKGS_SRC_TOP/$pkg $PKGS_DST_TOP/$pkg
	done
	
  # Generate config for OpenWRT SDK
	cd ../
  cp -uv ${MY_DOWNLOAD_DIR}/config.buildinfo .config
	make defconfig
	config_option_set CONFIG_DOWNLOAD_FOLDER  "\"$MY_DOWNLOAD_DIR\""

  # Find the target architecture, which is used as folder name: bin/packages/<arch>
  get_config_option CONFIG_TARGET_BOARD
  get_config_option CONFIG_TARGET_SUBTARGET
  get_config_option CONFIG_TARGET_ARCH_PACKAGES

	popd >/dev/null
}

generate_sdk_feeds_conf() {
  # Set SDK feeds.conf
  cp ${MY_DOWNLOAD_DIR}/feeds.buildinfo ${OPENWRT_SDK_DIR}/feeds.conf
  [ -f ${BUILDER_PROFILE_DIR}/feeds.extra.conf ] && cat ${BUILDER_PROFILE_DIR}/sdk/feeds.extra.conf >> ${OPENWRT_SDK_DIR}/feeds.conf || true
}

generate_ib_repositories_conf() {
	add_feed_to_repositories_conf local-kouhj file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/kouhj
	add_feed_to_repositories_conf local-base file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/base
	add_feed_to_repositories_conf local-luci file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/luci
	add_feed_to_repositories_conf local-packages ${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/packages
	add_feed_to_repositories_conf local-routing ${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/routing
	add_feed_to_repositories_conf local-telephony ${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/telephony
	#add_feed_to_repositories_conf stangri https://repo.openwrt.melmac.net
}

# Add key-build.pub file for package signature checking
add_key_file() {
	local KEY_FILE=$1
	cp -uv $KEY_FILE   ${OPENWRT_IB_DIR}/keys/`${OPENWRT_IB_DIR}/staging_dir/host/bin/usign -F -p $KEY_FILE`
}

#TODO: not used yet
add_sdk_keys_to_ib() {
	cd  ${OPENWRT_IB_DIR}
	add_key_file ${KOUHJ_SRC_DIR}/key-build.pub
	mkdir -p files/etc/opkg/
	# Add the official snapshot key 
	cp -a keys files/etc/opkg/
}

_docker_load_env