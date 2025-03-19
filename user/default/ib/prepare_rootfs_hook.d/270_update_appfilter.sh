export IPKG_INSTROOT=$1

FEATURE_LIB="${DL_CACHE_DIR}/feature_lib.tar.gz"
tar zxf $FEATURE_LIB ./feature.cfg -C ${IPKG_INSTROOT}/etc/appfilter/
tar zxf $FEATURE_LIB ./app_icons -C ${IPKG_INSTROOT}/www/luci-static/resources/

exit 0