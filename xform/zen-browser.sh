#!/bin/bash
# zen-browser.sh

firefox_deb_version=$1

if [ -z "$firefox_deb_version" ]
then
	echo "usage: $0 FIREFOX_DEB_VERSION"
	exit 1
fi

set -eu

top_dir=$(cd $(dirname $0) && cd .. && pwd)
. $top_dir/misc/functions.sh

base_dir=$PWD
orig_version=${firefox_deb_version%-*}
xtradeb_ci_commit=$(get_git_commit_id $top_dir)

##
section 'Check for required tools'
##

test -n "${CARGO:-}" || CARGO=cargo

run_cmd bwrap --version
run_cmd $CARGO --version
run_cmd jq --version
run_cmd npm --version

echo ' '

##
section 'Get zen-browser-debian Git tree'
## (conversion framework)
##

test -d zen-browser-debian \
|| run_cmd git clone --depth=1 https://salsa.debian.org/iskunk/zen-browser-debian.git

zen_debian_commit=$(get_git_commit_id zen-browser-debian)

echo ' '

##
section 'Get zen-browser/desktop Git tree'
## (source patches and scripts)
##

test -d zen-browser-desktop \
|| run_cmd git clone --depth=500 \
	https://github.com/zen-browser/desktop.git \
	zen-browser-desktop

echo ' '

# Get the Zen release tag that corresponds to the given Firefox version
zen_tag=$(zen-browser-debian/ff-version-to-zen-tag.sh $orig_version zen-browser-desktop)

echo "Using zen-browser tag \"$zen_tag\" for Firefox version \"$orig_version\""
run_cmd git -C zen-browser-desktop switch -d $zen_tag

zen_commit=$(git -C zen-browser-desktop log -n1 --pretty='%H')

echo ' '

##
section 'Get and unpack Firefox source'
## (as shipped by Debian)
##

mkdir -p source

(cd source && run_cmd ${APT_GET:-apt-get} --download-only source firefox=$firefox_deb_version)

dsc_file=$(cd source && echo firefox_*.dsc)
test -f source/$dsc_file \
|| error 'Cannot find Firefox source package .dsc file'

debian_tar_file=$(cd source && echo firefox_*.debian.tar.xz)
test -f source/$debian_tar_file \
|| error 'Cannot find Firefox source package .debian.tar.xz file'

echo ' '

run_cmd dscverify --verbose source/$dsc_file

echo ' '

rm -rf firefox-*

# Unpack source package
run_cmd dpkg-source \
	--no-copy \
	--skip-patches \
	--extract \
	source/$dsc_file

firefox_dir=$(echo firefox-*/debian/control | cut -d/ -f1)

test -d $firefox_dir/browser \
|| error 'Cannot find unpacked Firefox source package dir'

echo ' '

##
section 'Build Zen tooling'
##

# TEMPORARY: Patch Zen tooling
if [ ! -e zen-browser-desktop/.patched ]
then
	patch=zen-browser-debian/desktop-pr-13637.patch
	echo "NOTE: Applying $patch:"
	patch -d zen-browser-desktop -p1 < $patch
	touch zen-browser-desktop/.patched
	echo ' '
fi

mkdir -p ~/.cargo ~/.npm \
	zen-browser-desktop/node_modules \
	zen-browser-desktop/tools/ffprefs/target

(cd zen-browser-desktop/tools/ffprefs
 SECURE_WRAP_ALLOW_NETWORK=yes
 SECURE_WRAP_RW_DIRS="$HOME/.cargo $PWD/target"
 secure_wrap $CARGO build --locked
)

echo ' '

(cd zen-browser-desktop
 SECURE_WRAP_ALLOW_NETWORK=yes
 SECURE_WRAP_RW_DIRS="$HOME/.npm $PWD/node_modules"
 secure_wrap npm ci --ignore-scripts
)
echo ' '
# Exception to the --ignore-scripts regimen
(cd zen-browser-desktop/node_modules/sharp
 SECURE_WRAP_ALLOW_NETWORK=yes
 SECURE_WRAP_RW_DIRS="$HOME/.npm $PWD"
 secure_wrap npm run install
)

echo ' '

##
section 'Transform firefox -> zen-browser'
##

rm -rf _work
mkdir _work

(cd _work && run_cmd make -f ../zen-browser-debian/Makefile \
	check-git source-package \
	FIREFOX_SOURCE=../$firefox_dir \
	FIREFOX_ORIG=../source \
	ZEN_DESKTOP=../zen-browser-desktop \
	DEBIAN_XFORM=../zen-browser-debian \
	ADD_VERSION_SUFFIX=-1 \
	DISTRIBUTION= \
	SECURE_WRAP=$top_dir/misc/secure-wrap.sh
)

zen_deb_version=$(sed -n 's/^Version: *// p' _work/zen-browser_*.dsc)
test -n "$zen_deb_version" \
|| error 'Could not determine version of new zen-browser package'

section ''
echo ' '

rm -rf output
mkdir output
mv _work/zen-browser_* output/

checksums=
tab='	'
for file in output/*
do
	size=$(stat -Lc '%s' $file)
	sum=$(sha256sum $file | awk '{print $1}')
	checksums+="$tab$sum $size $(basename $file)
"
done

hr='================================================================'
echo $hr
tee output/INFO << END
# XtraDeb source package artifact info
Source: zen-browser
Version: $zen_deb_version
Transform-Base-Source: firefox
Transform-Base-Version: $firefox_deb_version
Transform-Source-Refs:
	xtradeb-ci@$xtradeb_ci_commit
	zen-browser-desktop@$zen_commit # $zen_tag
	zen-browser-debian@$zen_debian_commit
Checksums-Sha256:
$checksums
END
echo $hr

echo ' '

run_cmd ls -Ll output

# end zen-browser.sh
