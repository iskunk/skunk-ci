#!/bin/bash
# ungoogled-chromium.sh

chromium_deb_version=$1

set -eu

top_dir=$(cd $(dirname $0) && cd .. && pwd)
. $top_dir/misc/functions.sh

base_dir=$PWD
orig_version=${chromium_deb_version%-*}
xtradeb_ci_commit=$(get_git_commit_id $top_dir)

##
section 'Get ungoogled-chromium Git tree'
## (source patches and scripts)
##

test -d ungoogled-chromium \
|| run_cmd git clone --depth=10 https://github.com/ungoogled-software/ungoogled-chromium.git

uc_commit=$(get_git_commit_id ungoogled-chromium)

uc_tag=$(git -C ungoogled-chromium tag --list --sort=version:refname "$orig_version-*" | tail -n1)
test -n "$uc_tag" || error "cannot find matching tag for $orig_version"

uc_rev=${uc_tag##*-}

echo ' '

echo "Using ungoogled-chromium tag \"$uc_tag\""
run_cmd git -C ungoogled-chromium switch -d $uc_tag

echo ' '

##
section 'Get ungoogled-chromium-debian Git tree'
## (conversion framework)
##

test -d ungoogled-chromium-debian \
|| run_cmd git clone --depth=1 https://github.com/ungoogled-software/ungoogled-chromium-debian.git

test -f ungoogled-chromium-debian/convert/Makefile \
|| error 'cannot find ungoogled-chromium-debian conversion framework'

ucd_commit=$(get_git_commit_id ungoogled-chromium-debian)
work_dir=ungoogled-chromium-debian/convert

echo ' '

##
section 'Get and unpack Chromium source'
## (as shipped by Debian)
##

run_cmd ${APT_GET:-apt-get} --download-only source chromium=$chromium_deb_version

dsc_file=$(echo chromium_*.dsc)
test -f $dsc_file || error 'Cannot find Chromium source package .dsc file'
debian_tar_file=$(echo chromium_*.debian.tar.xz)
test -f $debian_tar_file || error 'Cannot find Chromium source package .debian.tar.xz file'
orig_tar_file=$(echo chromium_*.orig.tar.xz)
test -f $orig_tar_file || error 'Cannot find Chromium source package .orig.tar.xz file'

echo ' '

run_cmd dscverify --verbose $dsc_file

echo ' '

# Unpack source package
(cd $work_dir && run_cmd dpkg-source \
	--no-copy \
	--skip-patches \
	--extract \
	../../$dsc_file
)

chromium_dir=$(cd $work_dir && echo chromium-*/debian/control | cut -d/ -f1)

test -d $work_dir/$chromium_dir || error 'Cannot find Chromium source package dir'

echo ' '

##
section 'Transform chromium -> ungoogled-chromium'
##

SECURE_WRAP_RW_DIRS=$base_dir/$work_dir

(cd $work_dir && secure_wrap make \
	check-git source-package clean \
	VERSION=$orig_version \
	ORIG_SOURCE=$chromium_dir \
	ORIG_TARBALL=$base_dir/$orig_tar_file \
	UNGOOGLED=../../ungoogled-chromium \
	ADD_VERSION_SUFFIX=.$uc_rev \
	DISTRIBUTION= \
	INPLACE=1
)

uc_deb_version=$(dpkg-parsechangelog -l $work_dir/$chromium_dir/debian/changelog -S Version)

rm -rf $work_dir/$chromium_dir

section ''
echo ' '

rm -rf output
mkdir output
mv $work_dir/ungoogled-chromium_* output/

checksums=
tab='	'
for file in output/*
do
	size=$(stat -c '%s' $file)
	sum=$(sha256sum $file | awk '{print $1}')
	checksums+="$tab$sum $size $(basename $file)
"
done

hr='================================================================'
echo $hr
tee output/INFO << END
# XtraDeb source package transformation info
Source: ungoogled-chromium
Version: $uc_deb_version
Base-Source: chromium
Base-Version: $chromium_deb_version
Base-Orig-Tarballs: $orig_tar_file
Transform-Source-Refs:
	xtradeb-ci@$xtradeb_ci_commit
	ungoogled-chromium@$uc_commit # $uc_tag
	ungoogled-chromium-debian@$ucd_commit
Checksums-Sha256:
$checksums
END
echo $hr

echo ' '

run_cmd ls -Ll output

# end ungoogled-chromium.sh
