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
section 'Get zen-browser/desktop Git tree'
## (source patches and scripts)
##

test -d zen-browser-desktop \
|| run_cmd git clone --depth=500 \
	https://github.com/zen-browser/desktop.git \
	zen-browser-desktop

# Find the Zen release tag that corresponds to the given Firefox version

version_regex="^\\s*\"version\":\\s*\"${orig_version//./\\.}\","

zen_commit_pre=$(git -C zen-browser-desktop log -G"$version_regex" --pretty='%H' -- surfer.json \
	| tail -n1)
test -n "$zen_commit_pre" \
|| error "No matching commit found for version \"$orig_version\""

zen_tag=$(git -C zen-browser-desktop tag --contains=$zen_commit_pre --sort=-creatordate \
	| tail -n1)
test -n "$zen_tag" \
|| error "No matching tag found for commit \"$zen_commit_pre\" (version \"$orig_version\")"

grep -Pqx '\d\.\d\d(\.\d{1,2})?b?' <<< $zen_tag \
|| error "Got invalid tag \"$zen_tag\" for commit \"$zen_commit_pre\" (version \"$orig_version\")"

zen_commit=$(git -C zen-browser-desktop log -n1 --pretty='%H')

echo ' '

echo "Using zen-browser tag \"$zen_tag\" for Firefox version \"$orig_version\""
run_cmd git -C zen-browser-desktop switch -d $zen_tag

grep -Eq "$version_regex" zen-browser-desktop/surfer.json \
|| error 'That was not the right tag!'

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
patch=zen-browser-debian/desktop-pr-13637.patch
echo "NOTE: Applying $patch:"
(cd zen-browser-desktop && patch -p1) < $patch
echo ' '

(cd zen-browser-desktop/tools/ffprefs && run_cmd $CARGO build --locked)

echo ' '

(cd zen-browser-desktop && run_cmd npm ci --ignore-scripts)
echo ' '
(set -x; cd zen-browser-desktop/node_modules/sharp && npm run install)

echo ' '

##
section 'Transform firefox -> zen-browser'
##

rm -rf _work
mkdir _work

SECURE_WRAP_RW_DIRS=$base_dir/_work

(cd _work && secure_wrap make -f ../zen-browser-debian/Makefile \
	check-git source-package \
	FIREFOX_SOURCE=../$firefox_dir \
	FIREFOX_ORIG=../source \
	ZEN_DESKTOP=../zen-browser-desktop \
	DEBIAN_XFORM=../zen-browser-debian \
	ADD_VERSION_SUFFIX=-1 \
	DISTRIBUTION= \
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
