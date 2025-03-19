export IPKG_INSTROOT=$1

# This script installs the latest version of the OpenAppFilter feature library
FEATURE_LIB_FILENAME='feature3.0_cn_25.03.16-free.zip'  # Update as needed
FEATURE_LIB_URL="https://www.openappfilter.com/fros/download_feature?filename=${FEATURE_LIB_FILENAME}&f=1"

TMP_DIR=$(mktemp -d)
pushd $TMP_DIR

wget "$FEATURE_LIB_URL" -O f.zip

unzip f.zip
find . -type f | grep bin | xargs tar zxf
cp -af feature.cfg ${IPKG_INSTROOT}/etc/appfilter/
cp -af app_icons ${IPKG_INSTROOT}/www/luci-static/resources/

popd
rm -rf $TMP_DIR
exit 0