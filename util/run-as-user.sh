#!/bin/sh
# run-as-user.sh
#
# Simple script to run a command as a regular user (and create said regular
# user if it doesn't already exist).
#

user=build

exec 2>&1

if [ $(id -u) -ne 0 ]
then
	echo "$0: error: this script must run as root"
	exit 1
fi

set -e

if ! grep -q "^$user:" /etc/passwd
then
	(set -x
	 useradd \
		--comment 'Build User' \
		--gid users \
		--create-home \
		$user
	)
fi

test -n "$*" || exit 0

exec setpriv \
	--reuid=$user \
	--regid=users \
	--init-groups \
	--no-new-privs \
	--reset-env \
	/bin/sh -ex -c "$@"

# end run-as-user.sh
