#!/bin/sh
# multi-release.sh
#
# Usage examples:
#
#     multi-release 'origin/ubuntu/*'
#     multi-release bullseye bookworm
#

branches_spec=$*

set -e

get_conf()
{
	local key="$1"
	sed -n "s/^$key *= *//p" .merge.conf
}

branch_list=$(git branch --list --all --format='%(refname:short)' $branches_spec | sed 's,^origin/,,')

dir=$(dirname $0)
ok=yes

rm -f branch-list

for branch in $branch_list
do
	git switch $branch

	test -f .merge.conf || continue

	enabled=$(get_conf enabled)
	test "_$enabled" != _no || continue

	from_branch=$(get_conf from)
	codename=$(get_conf codename)
	suffix=$(get_conf suffix)

	test -z "$MULTI_RELEASE_FROM_OVERRIDE" \
	|| from_branch=$MULTI_RELEASE_FROM_OVERRIDE

	if $dir/merge-release.sh $from_branch $codename $suffix
	then
		echo $branch >> branch-list
	else
		ret=$?
		test $ret -ne 4 || ok=no
	fi

	echo ' '
done

test $ok = yes

# end multi-release.sh
