#!/bin/sh
# multi-merge.sh
#
# Usage examples:
#
#     multi-merge.sh 'origin/ubuntu/*'
#     multi-merge.sh bullseye bookworm
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

	test -z "$MULTI_MERGE_FROM_OVERRIDE" \
	|| from_branch=$MULTI_MERGE_FROM_OVERRIDE

	if $dir/merge-branch.sh $from_branch $codename $suffix
	then
		echo $branch >> branch-list
	else
		test $? -eq 2 || git merge --abort
		ok=no
	fi

	echo ' '
done

test $ok = yes

# end multi-merge.sh
