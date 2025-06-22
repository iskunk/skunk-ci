#!/bin/bash
# special-get-source.sh

set -e
exec 2>&1

prepare=no

if [ "x$1" = x--prepare ]
then
	prepare=yes
	shift
fi

package=$1
version=$2

error()
{
	echo "Error: $1"
	exit 1
}

test -n "$version" || error 'A version must be specified'

parse_debian_version()
{
	upstream_version=${version%-*}
	deb_version_part=${version##*-}

	test -n "$deb_version_part" \
	|| error "Version \"$version\" has no Debian suffix"
}

# Set this to a non-empty value to use a GitHub cache under ./upstream/
cache_version=

upstream_version=

case $package in

	chromium) #================================================

	parse_debian_version
	echo "$upstream_version" | grep -Pq '^\d{3}(\.\d{1,4}){3}$' \
	|| error "Invalid Chromium upstream version \"$upstream_version\""

	deb_tarball=chromium_$version.debian.tar.xz
	deb_tarball_url_list=$(echo \
		https://mirrors.wikimedia.org/debian/pool/main/c/chromium/$deb_tarball \
		https://incoming.debian.org/debian-buildd/pool/main/c/chromium/$deb_tarball \
	)

	src_tarball=chromium-$upstream_version-linux.tar.xz
	src_tarball_url=https://github.com/chromium-linux-tarballs/chromium-tarballs/releases/download/$upstream_version/$src_tarball

	if [ $prepare = yes ]
	then
		echo 'Will download:'
		echo "  DEBIAN_MIRROR_OR_INCOMING/$deb_tarball"
		echo "  $src_tarball_url"
	else
		mkdir source
		(cd source
		 for url in $deb_tarball_url_list FAIL
		 do
			test $url != FAIL || exit 1
			! (set -x; wget --progress=dot $url) || break
		 done

		 set -x
		 wget --progress=dot:giga $src_tarball_url

		 tar xJf $src_tarball
		 tar xJf $deb_tarball -C chromium-$upstream_version

		 # Don't bother with the get-orig-source process
		 mv $src_tarball chromium_$upstream_version.orig.tar.xz
		)
	fi
	;;

	firefox) #================================================

	parse_debian_version
	echo "$upstream_version" \
	| grep -Pq '^\d{3}(\.\d{1,2}){2}(\+build\d{1,2})?$' \
	|| error "Invalid Firefox upstream version \"$upstream_version\""

	ppa_url=https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu/pool/main/f/firefox

	dsc=firefox_$version.dsc
	dsc_url=$ppa_url/$dsc

	deb_tarball=firefox_$version.debian.tar.xz
	deb_tarball_url=$ppa_url/$deb_tarball

	src_tarball=firefox_$upstream_version.orig.tar.xz
	src_tarball_url=$ppa_url/$src_tarball

	if [ $prepare = yes ]
	then
		cache_version=$upstream_version

		echo 'Will download:'
		echo "  $dsc_url"
		echo "  $deb_tarball_url"
		echo "  $src_tarball_url"
		echo ' '
		echo 'Upstream source tarball will be cached.'
	else
		mkdir source
		(cd source; set -x; wget --progress=dot:mega $dsc_url $deb_tarball_url)
		echo ' '

		if [ ! -f upstream/$src_tarball ]
		then
			mkdir -p upstream
			# Use :mega as the download is fairly slow
			(cd upstream && set -x && wget --progress=dot:mega $src_tarball_url)
		fi

		ln upstream/$src_tarball source/

		(cd source; set -x; dpkg-source --skip-patches --extract $dsc)
	fi
	;;

	*) #================================================
	error "No special handling defined for package \"$package\""
	;;
esac

if [ $prepare = no -a -n "$upstream_version" ]
then
	test -f source/${package}_$upstream_version.orig.tar.xz \
	|| error 'Orig-source tarball is not in place'

	test -f source/$package-$upstream_version/debian/changelog \
	|| error 'Source tree was not correctly prepared'
fi

if [ -n "$GITHUB_OUTPUT" ]
then
	echo "cache-version=$cache_version" >> $GITHUB_OUTPUT
fi

# end special-get-source.sh
