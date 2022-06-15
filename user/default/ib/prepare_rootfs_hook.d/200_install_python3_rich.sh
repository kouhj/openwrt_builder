local GID=$(id -g)
cat > $1/tmp/install.sh <<- EOF
	#!/bin/sh +x
	/usr/bin/python3 -m pip install --upgrade pip
	pip3 install textual  # implicitly installs rich
	#find /usr ! -user $UID | xargs chown $UID:$GID
	# /tmp/resolv.conf may exist and cannot be removed
	rm -rf /tmp/* /tmp/.cache /dev/null || true
EOF

if [ -z "$CONFIG_ARCH" ]; then
	echo "CONFIG_ARCH is not set."
	exit 1
elif compgen -c qemu-${CONFIG_ARCH} > /dev/null; then
	if [ "$CONFIG_ARCH" == "x86_64" ]; then
		proot -r $1 -0 -b /etc/resolv.conf /bin/sh /tmp/install.sh
	else
		proot -R $1 -0 -b /etc/resolv.conf -q qemu-${CONFIG_ARCH} /bin/sh /tmp/install.sh
	fi
else
	echo "CONFIG_ARCH=$CONFIG_ARCH is not supported by qemu-user."
	exit 1
fi

