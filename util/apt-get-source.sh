#!/bin/sh
# apt-get-source.sh

origin=$1
package=$2
version=$3

set -e

for keyring in \
	/usr/share/keyrings/debian-archive-keyring.gpg \
	/usr/share/keyrings/ubuntu-archive-keyring.gpg
do
	if [ ! -f $keyring ]
	then
		echo "$0: error: $keyring: missing keyring file"
		exit 1
	fi
done

if [ ! -d ~/.chdist/"$origin" ]
then
	case "$origin" in
		debian-incoming)
		cat > tmp.$origin.sources << END
Types: deb-src
#URIs: https://deb.debian.org/debian
URIs: http://debian-archive.trafficmanager.net/debian
Suites: unstable
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb-src
URIs: https://incoming.debian.org/debian-buildd
Suites: buildd-unstable
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
END
		;;

		debian-unstable)
		cat > tmp.$origin.sources << END
Types: deb-src
#URIs: https://deb.debian.org/debian
URIs: http://debian-archive.trafficmanager.net/debian
Suites: unstable
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
END
		;;

		ubuntu-devel)
		cat > tmp.$origin.sources << END
Types: deb-src
#URIs: https://us.archive.ubuntu.com/ubuntu
URIs: http://azure.archive.ubuntu.com/ubuntu
Suites: devel
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
END
		;;

		*)
		echo "$0: error: unknown origin \"$origin\""
		exit 1
		;;
	esac

	chdist create $origin http://apt.example.com/debian stable main

	rm ~/.chdist/$origin/etc/apt/sources.list
	mv tmp.$origin.sources \
		~/.chdist/$origin/etc/apt/sources.list.d/$origin.sources
fi

(set -x; chdist apt-get $origin update)

if [ -n "$version" ]
then
	found_version=$(chdist apt-cache $origin --no-all-versions show $package \
		| sed -n 's/^Version: //p')
	if [ "_$found_version" != "_$version" ]
	then
		echo "$0: error: found version \"$found_version\", not the required \"$version\""
		exit 1
	fi
fi

(set -x; chdist apt-get $origin source --download-only $package)

# end apt-get-source.sh
