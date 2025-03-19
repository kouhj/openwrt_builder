export IPKG_INSTROOT=$1

FEATURE_LIB="${DL_CACHE_DIR}/feature_lib.tar.gz"
tar zxf $FEATURE_LIB ./feature.cfg ${IPKG_INSTROOT}/etc/appfilter/
tar zxf $FEATURE_LIB ./app_icons ${IPKG_INSTROOT}/www/luci-static/resources/

exit 0