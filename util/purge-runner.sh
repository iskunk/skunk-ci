#!/bin/sh
# purge-runner.sh
#
# Delete unnecessary files on the runner to free up space
#

set -e
exec 2>&1

test -d /HOST && cd /HOST || cd /

sudo=$(test $(id -u) -eq 0 || echo sudo)

echo 'Before:'
df -m .

echo ' '

for dir in \
	usr/local/.ghcup \
	usr/local/lib/android \
	usr/local/share/powershell \
	usr/share/dotnet \
	usr/share/swift
do
	(set -x; $sudo rm -rf $dir)
done

echo ' '

echo 'After:'
df -m .

# end purge-runner.sh
