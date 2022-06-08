# Disable DHCP on LAN by default
sed -i "s/interface.*lan/&\n\t 	option ignore '1'/" $1/etc/config/dhcp
