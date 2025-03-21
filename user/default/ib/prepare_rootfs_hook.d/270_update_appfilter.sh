export IPKG_INSTROOT=$1

FEATURE_LIB="${DL_CACHE_DIR}/feature_lib.tar.gz"
tar zxf $FEATURE_LIB ./feature.cfg -C ${IPKG_INSTROOT}/etc/appfilter/
tar zxf $FEATURE_LIB ./app_icons -C ${IPKG_INSTROOT}/www/luci-static/resources/
ls -l ${IPKG_INSTROOT}/etc/appfilter

if ! grep -q IPKG_INSTROOT ${IPKG_INSTROOT}/etc/init.d/appfilter; then
	TMPFILE="/tmp/appfilter.patch"
	cat > $TMPFILE  << 'EOF'
--- a/etc/init.d/appfilter
+++ b/etc/init.d/appfilter
@@ -1,6 +1,6 @@
 #!/bin/sh /etc/rc.common
-. /usr/share/libubox/jshn.sh
-. /lib/functions.sh
+. ${IPKG_INSTROOT}/usr/share/libubox/jshn.sh
+. ${IPKG_INSTROOT}/lib/functions.sh

 START=96
 USE_PROCD=1
@@ -15,7 +15,7 @@
        test -f $FEATURE_FILE &&{
                rm $FEATURE_FILE
        }
-       ln -s /etc/appfilter/feature.cfg $FEATURE_FILE
+       ln -s ${IPKG_INSTROOT}/etc/appfilter/feature.cfg $FEATURE_FILE
        procd_open_instance
        procd_set_param respawn 60 5 5
        procd_set_param stderr 1


exit 0
EOF

	patch -p1 < $TMPFILE
	rm -f ${IPKG_INSTROOT}/etc/init.d/*.orig
	rm -f $TMPFILE
fi