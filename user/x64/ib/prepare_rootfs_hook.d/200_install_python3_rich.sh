local GID=$(id -g)
cat > $1/tmp/install.sh <<- EOF
	#!/bin/sh
	/usr/bin/python3 -m pip install --upgrade pip
	pip3 install rich
	find /usr ! -user $UID | xargs chown $UID:$GID
	rm -rf /tmp/* /tmp/.cache /dev/null
EOF
sudo chroot $1 /bin/sh /tmp/install.sh
