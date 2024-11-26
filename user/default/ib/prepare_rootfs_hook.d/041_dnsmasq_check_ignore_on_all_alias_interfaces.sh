# DO NOT RUN SHELLFORMAT AGAINST THIS FILE !!!
# THIS FILE IS SOURCED BY THE BUILDER

# Enable check on all alias interfaces for the option ignore in dnsmasq
pushd "${OPENWRT_IB_ROOTFS_DIR}"
if ! grep -q interface_and_aliases_are_all_ignored etc/init.d/dnsmasq; then
	$TMPFILE="/tmp/dnsmasq.patch"
	cat > $TMPFILE  << 'EOF'

--- a/etc/init.d/dnsmasq
+++ b/etc/init.d/dnsmasq
@@ -509,6 +509,22 @@
 	dhcp_option_add "$cfg" "$networkid" "$force"
 }
 
+# In case the interface($net) is an alias, which is created by "option device '@master'",
+# or the interface has aliased interfaces, we should check if all interfaces, including
+# the master interface and the aliased interfaces, have "option ignore '1'".
+interface_and_aliases_are_all_ignored() {
+	local __network
+	local __ifname
+	local __ignore
+
+	for __network in $(uci show network | grep '=interface' | sed -r 's/.*network\.([^=]+)=.*/\1/g'); do
+		network_get_device __ifname "$__network"
+		[ "$__ifname" = "$ifname" ] || continue
+		__ignore=$(uci -q get dhcp."$__network".ignore 2>/dev/null)
+		[ "$__ignore" != '1' ] && return 1
+	done  
+	return 0
+}
 
 dhcp_add() {
 	local cfg="$1"
@@ -528,11 +544,13 @@
 		DNS_SERVERS="$DNS_SERVERS $dnsserver"
 	}
 
-	append_bool "$cfg" ignore "--no-dhcp-interface=$ifname" && {
+	config_get ignore "$cfg" ignore 0
+	if [ "$ignore" -gt 0 ]; then
+		interface_and_aliases_are_all_ignored && xappend "--no-dhcp-interface=$ifname"
 		# Many ISP do not have useful names for DHCP customers (your WAN).
 		dhcp_this_host_add "$net" "$ifname" "$ADD_WAN_FQDN"
 		return 0
-	}
+	fi
 
 	network_get_subnet subnet "$net" || return 0
 	network_get_protocol proto "$net" || return 0

EOF

	patch -p1 < $TMPFILE
	rm -f $TMPFILE
fi
popd

