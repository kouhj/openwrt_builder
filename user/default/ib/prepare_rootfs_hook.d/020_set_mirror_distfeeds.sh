# Change OpenWRT distfeeds to Tencent mirror
sed -i 's_https://downloads.openwrt.org_http://mirrors.tuna.tsinghua.edu.cn/openwrt_' $1/etc/opkg/distfeeds.conf
