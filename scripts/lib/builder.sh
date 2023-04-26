#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
#      This file contains the common routines used by the image builer.
# Lisence: MIT
# Author: kouhj
#========================================================================================

# Conditional sourcing avoid sourcing twice
initialize() {
	if ! LC_ALL=C type -t _set_env >/dev/null; then
		if [ -f /.dockerenv ]; then
			local BASE_DIR="/home/builder"
		else
			local BASE_DIR="${HOST_WORK_DIR}"
		fi
		source "${BASE_DIR}/scripts/lib/gaction.sh"
	fi
	_docker_load_env
}

# Add package feed to repo with name $1 and URL $2
add_feed_to_repositories_conf() {
	if ! grep -q $1 repositories.conf; then
		echo "src/gz $1 $2" >>repositories.conf
	fi
}

# Add package feed to repo with type $1 name $2 and URL $3
add_feed_to_feeds_conf() {
	if ! grep -q $2 feeds.conf; then
		echo "$1 $2 $3" >>feeds.conf
	fi
}

# Select config file $1 with key $2 to value $3(yes|no|module)
config_option_select() {
	if grep -q -w $2 $1; then # update the option if it exists
		[[ "$3" == 'y' || "$3" == 'yes' || "$3" == 'm' || "$3" == 'module' ]] && (
			sed -i -r "s~^.*($2)[= ].*\$~\1=${3:0:1}~" $1
		) || (
			sed -i -r "s/^($2)=.*/\# \1 is not set/" $1
		)
	else # this option does not exist in the .config file
		[[ "$3" == 'y' || "$3" == 'yes' || "$3" == 'm' || "$3" == 'module' ]] && (
			echo "$2=${3:0:1}" >>$1
		) || (
			echo "# $2 is not set" >>$1
		)
	fi
	grep -w $2 $1
}

# Set config file $1 with key $2 to value $3
config_option_set() {
	if grep -q -w $2 $1; then # update the option if it exists
		sed -i -r "s~^.*($2)[= ].*\$~\1=$3~" $1
	else # this option does not exist in the .config file
		echo "$2=$3" >>$1
	fi
	grep -w $2 $1
}

# Get config file $1 with key $2, and set it as a docker environment variable
get_config_option() {
	local v=$(sed -n -r 's/'$2'="*([^"]+)"*/\1/p' $1)
	eval "export $2=$v"
	_docker_set_env $2
}

# Update config file ($1) with new values from file ($2)
# $1: config file
# $2: file with new values
update_config_from_file() {
	local key value
	local regex_comment="^# .* is not set"
	local regex_option="^\s*CONFIG.*=.*"

	#set -x
	while read line; do
		echo $line
		if [[ $line =~ $regex_comment ]]; then
			key=$(echo $line | sed -r 's/#\s+(CONFIG.*) is not set/\1/') # Get the key name from the comment
			config_option_select $1 $key no                              # and set it into the .config file
		elif [[ $line =~ $regex_option ]]; then
			local key=${line%%=*}
			local value=${line#*=}
			config_option_set $1 $key $value
		fi
	done <$2
}

generate_openwrt_sdk_config() {
	local CONFIG_FILE="${OPENWRT_SDK_DIR}/.config"

	cd "${OPENWRT_SDK_DIR}"
	cp -a ${OPENWRT_IB_DIR}/.config.orig ${CONFIG_FILE}
	config_option_set ${CONFIG_FILE} CONFIG_DOWNLOAD_FOLDER "\"${MY_DOWNLOAD_DIR}/sdk\""

	# Update config file with new values from user/current/sdk/config*.diff
	for file in $(compgen -G "${BUILDER_PROFILE_DIR}/sdk/config*.diff"); do
		update_config_from_file ${CONFIG_FILE} ${file}
	done

	# This will fix the necesary options due to the manual configuration changes above
	make defconfig
}


get_openwrt_sdk_config_options() {
	local CONFIG_FILE="${OPENWRT_SDK_DIR}/.config"
		
	cd "${OPENWRT_SDK_DIR}"
	get_config_option ${CONFIG_FILE} CONFIG_ARCH
	get_config_option ${CONFIG_FILE} CONFIG_TARGET_BOARD
	get_config_option ${CONFIG_FILE} CONFIG_TARGET_SUFFIX
	get_config_option ${CONFIG_FILE} CONFIG_TARGET_SUBTARGET
	get_config_option ${CONFIG_FILE} CONFIG_TARGET_ARCH_PACKAGES
}


generate_openwrt_ib_config() {
	local CONFIG_FILE="${OPENWRT_IB_DIR}/.config"

	cd "${OPENWRT_IB_DIR}"
	cp -a ${OPENWRT_IB_DIR}/.config.orig ${CONFIG_FILE}

	config_option_set ${CONFIG_FILE} CONFIG_DOWNLOAD_FOLDER "\"${MY_DOWNLOAD_DIR}/ib\""

	# Update config file with new values from user/current/sdk/config*.diff
	for file in $(compgen -G "${BUILDER_PROFILE_DIR}/ib/config*.diff"); do
		update_config_from_file ${CONFIG_FILE} ${file}
	done

	# NOTE: do not run 'make *config' here, it will cause error
}

openwrt_sdk_install_ksoftethervpn() {
	local PKGS_SRC_TOP="$OPENWRT_CUR_DIR/package"
	local PKGS_DST_TOP="$OPENWRT_SDK_DIR/package"
	pushd $PKGS_DST_TOP

	set -x
	mkdir -p feeds feeds/luci kernel libs utils system feeds/pacakges/curl feeds/packages/gawk feeds/packages/net feeds/packages/libs

	# Extra package dependencies for ksoftethervpn
	for lib in zlib libiconv ncurses openssl readline libjson-c libubox libnl-tiny nettle gmp libevent2 libmnl; do
			[ -h $PKGS_DST_TOP/libs/$lib ] || ln -sf $PKGS_SRC_TOP/libs/$lib $PKGS_DST_TOP/libs/
	done
	for pkg in feeds/kouhj feeds/luci/luci-base feeds/packages/libs/gnutls feeds/packages/net/unbound feeds/packages/libs/expat\
				kernel/cryptodev-linux utils/lua utils/ucode system/ubus system/uci system/ca-certificates; do
			[ -h $PKGS_DST_TOP/$pkg ] || ln -sf $PKGS_SRC_TOP/$pkg $PKGS_DST_TOP/$pkg
	done
	for inc in openssl-module.mk; do
			[ -h $OPENWRT_SDK_DIR/include/$inc ] || ln -sf $OPENWRT_CUR_DIR/include/$inc $OPENWRT_SDK_DIR/include/
	done

	popd >/dev/null

	# Update config for OpenWRT SDK
	for pkg in ksoftethervpn-server ksoftethervpn-client chnroutes luci-app-chnroutes config-script dnspod-script wireguard-script smartdns-list-update; do
		config_option_select ${OPENWRT_SDK_DIR}/.config CONFIG_PACKAGE_${pkg} module
	done

	make defconfig # Auto select the dependant packages
}

# Modify ImageBuilder config options
config_openwrt_ib() {
	cd $OPENWRT_IB_DIR
	config_option_set CONFIG_DOWNLOAD_FOLDER "\"$MY_DOWNLOAD_DIR/pkgs\""
	case "$CONFIG_TARGET_ARCH_PACKAGES" in
	x86_64)
		config_option_set CONFIG_TARGET_ROOTFS_PARTSIZE 128
		config_option_select CONFIG_GRUB_IMAGES no
		config_option_select CONFIG_TARGET_ROOTFS_EXT4FS no
		config_option_select CONFIG_VHDX_IMAGES no
		;;

	aarch64_cortex-a53)
		:
		# Nothing so far
		;;

	esac
}

# Generate feeds.conf from IB's feeds.buildinfo and user/current/feeds.conf
do_generate_feeds_conf() {
	# Set SDK feeds.conf
	cp ${MY_DOWNLOAD_DIR}/feeds.buildinfo $2/feeds.conf

	for file in $(compgen -G "${BUILDER_PROFILE_DIR}/$1/feeds*.conf"); do
		cat $file >>$2/feeds.conf
	done
}

generate_source_feeds_conf() {
	do_generate_feeds_conf source ${OPENWRT_CUR_DIR}
}

generate_sdk_feeds_conf() {
	do_generate_feeds_conf sdk ${OPENWRT_SDK_DIR}
}

# Update IB/repositories.conf from SDK/bin/packages/ARCH/* folders and user/current/feeds*.conf files
update_ib_repositories_conf() {
	add_feed_to_repositories_conf local-kouhj file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/kouhj
	add_feed_to_repositories_conf local-base file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/base
	add_feed_to_repositories_conf local-luci file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/luci
	add_feed_to_repositories_conf local-packages file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/packages
	add_feed_to_repositories_conf local-routing file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/routing
	add_feed_to_repositories_conf local-telephony file:${OPENWRT_SDK_DIR}/bin/packages/${CONFIG_TARGET_ARCH_PACKAGES}/telephony

	for file in $(compgen -G "${BUILDER_PROFILE_DIR}/ib/feeds*.conf"); do
		while read line; do
			if ! grep -q "$line" ${OPENWRT_IB_DIR}/repositories.conf; then
				echo "$line" >>${OPENWRT_IB_DIR}/repositories.conf
			fi
		done <$file
	done
}

# Add key-build.pub file for package signature checking
add_key_file() {
	local KEY_FILE=$1
	cp -uv $KEY_FILE ${OPENWRT_IB_DIR}/keys/$(${OPENWRT_IB_DIR}/staging_dir/host/bin/usign -F -p $KEY_FILE)
}

# Add SDK build key to IB's files/etc/opkg/ folder
add_sdk_keys_to_ib() {
	cd ${OPENWRT_IB_DIR}
	add_key_file ${KOUHJ_SRC_DIR}/key-build.pub
	mkdir -p files/etc/opkg/
	# Add the official snapshot key
	cp -a keys files/etc/opkg/
}

# Combine the list of packages from $* files.
# The files are assumed to be in the following format,
#     package1 package2 package3
#     package4
#     # comment lines staring with # are ignored
#     package5 package6 package7 package8
# and the output of the command is:
#     package1 package2 package3 package4 package5 package6 package7 package8
#
get_list_from_file() {
	local LIST
	while read line; do
		LIST+="$line "
	done < <(sed '/^#/d; /^$/d; s/\s+/ /g' $*)
	echo $LIST
}

# copy build keys from the private repo
copy_build_keys() {
	for file in ${KOUHJ_SRC_DIR}/key-build*; do
		cp -u $file ${OPENWRT_SDK_DIR}/
		cp -u $file ${OPENWRT_CUR_DIR}/
	done
}

# If use the legacy firewall instead of firewall4
USE_FIREWALL3=0

# Modify some default packages used by IB
patch_ib_default_packages() {
	sed -i 's/dnsmasq /dnsmasq-full /' ${OPENWRT_IB_DIR}/include/target.mk #Modify DEFAULT_PACKAGES
	
	if [ "$USE_FIREWALL3" -eq 1 ]; then
		if grep -q firewall4 include/target.mk; then                           # Switch from firewall4 to firewall3
			sed -i 's/firewall4 /firewall /; s/nftables/ip6tables/; s/kmod-nft-offload/kmod-ipt-offload/; /ip6tables/ a\\tiptables-legacy \\' include/target.mk
		fi
	fi
}

# Get the list of packages to be installed in the IB, which come from the following places:
# 1. The list of packages from official openwrt-*.manifest file of the pre-built firmware
# 2. The list of packages from the user/current/ib/packages*.txt files
get_packages_for_ib() {

	# Get the official package list of IB
	PKG_LIST='/tmp/opkg.list'
	touch packages/Packages.gz # make package_list fails if this file does not exist
	make package_list | awk '{if ($2 == "-") print $1}' > $PKG_LIST

	OPENWRT_IB_PACKAGES=$(
		(
			awk '{print $1}' "${MY_DOWNLOAD_DIR}/${OPENWRT_MF_FILE}" # Intial packages from the manifest file
			if compgen -G "${BUILDER_PROFILE_DIR}/ib/packages*.ssv" >/dev/null; then
				get_list_from_file ${BUILDER_PROFILE_DIR}/ib/packages*.ssv # Additional packages from the profile dir
			fi
			# NOTE: stream to sed below is in the one-word-per-line format, not the space-separated format
		) | sed 's/dnsmasq//' | # Will be included in include/target.mk as DEFAULT_PACKAGES

		while read pkg; do # For each package, if its suffix is YYYYMMdd, update to the newer date in $PKG_LIST
			if [[ $pkg =~ [0-9]{8}$ ]]; then
				pkg_prefix=${pkg:0:${#pkg}-8}
				egrep "${pkg_prefix}[0-9]{8}$" $PKG_LIST || echo $pkg
			elif [[ $pkg =~ ^libwolfssl[0-9] ]]; then # libwolfssl5.5.1.ee39414e
				echo libwolfssl
			else
				echo $pkg
			fi
		done
	)

	rm -f $PKG_LIST

	if [ "$USE_FIREWALL3" -eq 1 ]; then
		OPENWRT_IB_PACKAGES=$(echo $OPENWRT_IB_PACKAGES | sed 's/firewall4 /firewall /; s/nftables /ip6tables iptables-legacy /; s/kmod-nft-offload/kmod-ipt-offload/; s/nftables-json//')
	else
		# Change from <LF> separated to SPACE separated
		OPENWRT_IB_PACKAGES=$(echo $OPENWRT_IB_PACKAGES)
	fi

	_docker_set_env OPENWRT_IB_PACKAGES
}

# Get the list of profiles to be compiled by the IB
get_profiles_for_ib() {
	OPENWRT_IB_PROFILE=$(# OpenWRT supprts only one PROFILE at a time
		if [ -f ${BUILDER_PROFILE_DIR}/ib/profile.ssv ]; then
			get_list_from_file ${BUILDER_PROFILE_DIR}/ib/profile.ssv
		fi
	)
	_docker_set_env OPENWRT_IB_PROFILE
}

# Generate the list of services to be disabled in the firmware built by IB, which come from the following places:
# 1. user/current/ib/disabled-services*.txt
get_disabled_services_for_ib() {
	OPENWRT_IB_DISABLED_SERVICES=$(
		if compgen -G "${BUILDER_PROFILE_DIR}/ib/disabled-services*.ssv" >/dev/null; then
			get_list_from_file ${BUILDER_PROFILE_DIR}/ib/disabled-services*.ssv
		fi
	)

	_docker_set_env OPENWRT_IB_DISABLED_SERVICES
}

# Apply the patches from user/current/{ib or sdk}/patches/*.patch
do_apply_patches_for_ib_or_sdk() {
	local PATCH_FILE_DIR=$1
	local PATCH_DEST_DIR=$2
	echo "Applying patches for $1..."
	if [ -n "$(ls -A "${PATCH_FILE_DIR}/patches" 2>/dev/null)" ]; then
		(
			if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
				set +eo pipefail
			fi

			find "${PATCH_FILE_DIR}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d '${PATCH_DEST_DIR}' -p0 --forward"
			## To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
			#true
		)
	fi
}

apply_patches_for_ib() {
	do_apply_patches_for_ib_or_sdk ${BUILDER_PROFILE_DIR}/ib ${OPENWRT_IB_DIR}
	patch_ib_default_packages
}

apply_patches_for_sdk() {
	do_apply_patches_for_ib_or_sdk ${BUILDER_PROFILE_DIR}/sdk ${OPENWRT_SDK_DIR}
}

prepare_rootfs_hook() {
	# Load the docker env vars, as it proved that the exported dokcer env vars were not inherited in the hook
	source "${BUILDER_WORK_DIR}/scripts/lib/builder.sh"
	cd ${OPENWRT_IB_DIR}
	set -eo pipefail
	for script in $(compgen -G "${BUILDER_PROFILE_DIR}/ib/prepare_rootfs_hook.d/*.sh" | sort); do
		if [ -f "$script" ]; then
			echo "Running prepare_rootfs_hook script: $script"
			set -x
			. "$script" ${OPENWRT_IB_ROOTFS_DIR}
			set +x
		fi
	done
}

export -f prepare_rootfs_hook

housekeep_local_downloads() {
	# Delete old files
	find ${MY_DOWNLOAD_DIR} -type f -ctime +7 -delete
}

# Download the specified file $1 from OpenWRT site and save as $2, without checking checksum before downloading
download_openwrt_file() {
	[ "${2:0:1}" == '/' ] && OUTFILE=$2 || OUTFILE="${MY_DOWNLOAD_DIR}/$2"
	[ -z "$2" ] && OUTFILE="${MY_DOWNLOAD_DIR}/$1"
	TMPFILE="/tmp/$(basename $OUTFILE)"
	if wget --no-check-certificate -q ${OPENWRT_DOWNLOAD_SITE_URL}/$1 -O ${TMPFILE}; then
		if cmp -s ${TMPFILE} ${OUTFILE}; then
			return 1 # the new download is the same as local
		else
			cp -af ${TMPFILE} ${OUTFILE}
		fi
	else
		return 2 # download failure
	fi
}

# Download the specified file $1 from OpenWRT site and save as $1. If the checksum hasn't changed, download is skipped.
download_openwrt_latest_file() {
	local DOWNLOAD_NEEDED=0
	if [ -f $1 ]; then
		if grep $1 sha256sums | sha256sum -c -; then
			echo "File $1 is up to date"
		else
			echo "File $1 is not up to date"
			rm $1
			DOWNLOAD_NEEDED=1
		fi
	else
		echo "File $1 does not exist"
		DOWNLOAD_NEEDED=1
	fi

	if [ $DOWNLOAD_NEEDED -eq 1 ]; then
		echo "Downloading $1"
		if download_openwrt_file $1; then
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

# Download a pre-built package
# $1: repo name, which could be: base, luci, packages, routing, telephony
# $2: package basename
download_ipk() {
	local REPO="$1" PKG_BN="$2"
	local URL_BASE="$OPENWRT_SITE_URL/packages/$ARCH/$REPO"
	local PACKAGES="$URL_BASE/Packages"

	local PACKAGE_NAME=$(curl $PACKAGES 2>/dev/null | awk '/Filename: '${PKG_BN}'[a-f0-9_\-\.]+(x86_64|all).ipk$/ {print $2}')
	local PACKAGE_URL="$URL_BASE/$PACKAGE_NAME"

	rm -f $MY_DOWNLOAD_DIR/pkgs/$PACKAGE_NAME
	wget $PACKAGE_URL -O $MY_DOWNLOAD_DIR/pkgs/$PACKAGE_NAME

	echo $PACKAGE_NAME
}

# This function pulls the pre-built \*.so files into the ipkg-install/usr/lib/ dir
fix_ucode_mods_for_openwrt_sdk() {
	set -x
	make package/ucode/prepare
	mkdir -p $(echo build_dir/target-${CONFIG_TARGET_ARCH_PACKAGES}_${CONFIG_TARGET_SUFFIX}/ucode-*)/ipkg-install
	ls -l build_dir/target-${CONFIG_TARGET_ARCH_PACKAGES}_${CONFIG_TARGET_SUFFIX}/
	for pkg in ucode-mod-nl80211 ucode-mod-rtnl; do
		local PKG_FILE_NAME=$(download_ipk base $pkg)
		tar zxf $DL_PATH/pkgs/$PKG_FILE_NAME ./data.tar.gz
		tar -C build_dir/target-${CONFIG_TARGET_ARCH_PACKAGES}_${CONFIG_TARGET_SUFFIX}/ucode-*/ipkg-install  -zvxf data.tar.gz
		rm -f data.tar.gz
	done
	set +x
}

compile() {
	(
		if [ "x${MODE}" = "xm" ]; then
			local nthread=$(($(nproc) + 2))
			echo "${nthread} thread compile: $*"
			make -j${nthread} "$@" || ( fix_ucode_mods_for_openwrt_sdk && make -j${nthread} "$@" )
		elif [ "x${MODE}" = "xs" ]; then
			echo "Fallback to single thread compile: $*"
			make -j1 V=s "$@"
		else
			echo "No MODE specified" >&2
			exit 1
		fi
	)
}

initialize
