#!/bin/sh
# setup.sh

set -e

export DEBIAN_FRONTEND=noninteractive

test -n "$APT_MIRROR"
test -n "$REG_UID"

run() {
	echo "+ $*"
	env "$@" 2>&1
	echo
}

# Adjust APT configuration
run tee /etc/apt/apt.conf.d/95custom << END
# Don't install recommended packages
APT::Install-Recommends "0";

# Don't use "Reading database ... X%" progress indicator
Dpkg::Use-Pty "false";
END

# Set up APT package repositories
if [ "_$APT_MIRROR" != _NONE ]
then
	run perl -pi \
		-e 's!deb.debian.org!<APT>!;' \
		-e 's!archive.ubuntu.com/ubuntu!<APT>/ubuntu!;' \
		-e 's!security.ubuntu.com/ubuntu!<APT>/ubuntu-security! if 0;' \
		-e "s!<APT>!$APT_MIRROR!;" \
		-e '/ \w+-(backports|security) / and s/^/#!#/' \
		/etc/apt/sources.list.d/*.sources
fi

run apt-get --error-on=any update
run apt-get -y dist-upgrade

run apt-get -y install \
	bubblewrap \
	ca-certificates \
	debhelper \
	debian-keyring \
	devscripts \
	dpkg-dev \
	equivs \
	file \
	git \
	jq \
	less \
	nano \
	netcat-openbsd \
	procps \
	python3 \
	quilt \
	rsync \
	sudo-rs \
	time \
	unzip \
	wget \
	xz-utils \
	zip \
	zstd

# Clean up
run apt-get clean
rm -f /var/lib/apt/lists/*debian*

# Create regular user
run useradd \
	--uid $REG_UID \
	--no-user-group \
	--comment 'Regular User' \
	--create-home \
	--key HOME_MODE=0755 \
	--shell /bin/bash \
	user

# Set up sudo-rs
run usermod -G sudo -a user
if [ -f /etc/sudoers ]
then
	echo 'error: /etc/sudoers already exists'
	exit 1
fi
run tee /etc/sudoers << END
# Delete this file to disable sudo access
%sudo	ALL=(ALL)	NOPASSWD: ALL
END
run ln -s /usr/lib/cargo/bin/sudo /usr/local/bin/

echo 'Setup done.'

# end setup.sh
