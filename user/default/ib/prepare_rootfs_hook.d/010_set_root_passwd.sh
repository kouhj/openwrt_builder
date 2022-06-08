#Modify password
sed -i 's_^root.*$_root:$1$K83z8tw0$gyr0Zga6SVZu85njEPbo8/:18992:0:99999:7:::_' $1/etc/shadow
