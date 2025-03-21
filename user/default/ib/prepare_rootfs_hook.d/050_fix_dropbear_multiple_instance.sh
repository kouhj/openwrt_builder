# DO NOT RUN SHELLFORMAT AGAINST THIS FILE !!!
# THIS FILE IS SOURCED BY THE BUILDER

export IPKG_INSTROOT=$1

# Fix dropbear multiple instance
pushd "${IPKG_INSTROOT}"
if ! grep -q if_ipaddrs etc/init.d/dropbear; then
	TMPFILE="/tmp/dropbear.patch"
	cat > $TMPFILE  << 'EOF'
--- a/etc/init.d/dropbear
+++ b/etc/init.d/dropbear
@@ -134,7 +134,7 @@ validate_section_dropbear()
 
 dropbear_instance()
 {
-	local ipaddrs
+	local ipaddrs if_ipaddrs
 
 	[ "$2" = 0 ] || {
 		echo "validation failed"
@@ -144,10 +144,13 @@ dropbear_instance()
 	[ -n "${Interface}" ] && {
 		[ -n "${BOOT}" ] && return 0
 
-		network_get_ipaddrs_all ipaddrs "${Interface}" || {
-			echo "interface ${Interface} has no physdev or physdev has no suitable ip"
-			return 1
-		}
+		for n in ${Interface}; do
+			network_get_ipaddrs_all if_ipaddrs $n || {
+				echo "interface $n has no physdev or physdev has no suitable ip"
+				return 1
+			}
+			ipaddrs="$ipaddrs $if_ipaddrs"
+		done
 	}
 
 	[ "${enable}" = "0" ] && return 1
EOF

	patch -p1 < $TMPFILE
	rm -f etc/init.d/*.orig
	rm -f $TMPFILE
fi
popd

