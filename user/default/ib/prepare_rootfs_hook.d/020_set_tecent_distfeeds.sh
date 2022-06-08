# Change OpenWRT distfeeds to Tencent mirror
sed -i 's_https://downloads.openwrt.org_https://mirrors.cloud.tencent.com/lede_' $1/etc/opkg/distfeeds.conf
