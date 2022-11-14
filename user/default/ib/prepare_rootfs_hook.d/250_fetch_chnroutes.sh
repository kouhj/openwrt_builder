echo Fetching the latest China routes ... this may take a while ...
curl 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' 2>/dev/null |
    grep CN > /tmp/chnroutes.full

if [ $? -eq 0 ]; then
    grep ipv4 /tmp/chnroutes.full | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > $1/etc/chnroutes.ipv4
    grep ipv6 /tmp/chnroutes.full | awk -F\| '{ printf("%s/%d\n", $4, $5) }' > $1/etc/chnroutes.ipv6
fi

rm -f /tmp/chnroutes.* 2>/dev/null
