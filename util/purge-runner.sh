#!/bin/sh
# purge-runner.sh
#
# Delete unnecessary files on the runner to free up space
#
# Cf. https://github.com/jlumbroso/free-disk-space
#

set -e
exec 2>&1

test -d /HOST && cd /HOST || cd /

sudo=$(test $(id -u) -eq 0 || echo sudo)

echo 'Before:'
df -m .

echo ' '

for dir in \
	etc/skel/.rustup \
	home/*/.rustup \
	opt/hostedtoolcache/* \
	usr/lib/google-cloud-sdk \
	usr/lib/jvm \
	usr/local/.ghcup \
	usr/local/julia* \
	usr/local/lib/android \
	usr/local/lib/node_modules \
	usr/local/share/chromium \
	usr/local/share/powershell \
	usr/share/dotnet \
	usr/share/miniconda \
	usr/share/swift
do
	$sudo find $dir -type f -exec truncate -s0 {} + || true
	(set -x; $sudo rm -rf $dir)
done

echo ' '

echo 'After:'
df -m .

# end purge-runner.sh
