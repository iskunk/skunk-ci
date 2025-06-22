#!/bin/bash
# merge-release.sh
#
# This script is used in the management of a Debian source package's Git
# repository (i.e. where the debian/ subdirectory contents are maintained).
#
# Its main purpose is to merge recent changes in the main branch (which
# usually targets Debian sid/unstable) into a branch for an alternate
# release/distribution (e.g. Debian stable, or some Ubuntu release), and
# then commit a new release to the Debian changelog. If there are no recent
# changes to merge, then it will check for unreleased changes in the target
# branch, and commit a release with those. If neither category of change is
# present, then no new release is committed.
#
# This should be run in the Git repository, with the target branch active.
#
# Usage: merge-release FROM_BRANCH REL_CODENAME REL_SUFFIX
#
# * FROM_BRANCH: Merge in changes from this branch
# * REL_CODENAME: Release codename for target distribution
# * REL_SUFFIX: Suffix to add to the version string, minus the final digit
#
# Example: merge-release main noble '~ubu2404u'
#
# Exit status:
#   0 - success
#   1 - merge failure
#   2 - precondition failure
#   4 - no new release (not an error)
#

from_branch="$1"
rel_codename="$2"
rel_suffix="$3"

set -e

rm -f tmp.commit-msg.txt

#
# Preliminary checks
#

if [ -z "$from_branch" -o -z "$rel_codename" -o -z "$rel_suffix" ]
then
	echo 'error: this script requires arguments'
	exit 2
fi

if [ -z "$DEBFULLNAME" -o -z "$DEBEMAIL" ]
then
	echo 'error: please set DEBFULLNAME and DEBEMAIL in the environment'
	exit 2
fi

if [ ! -f .git/index ] || ! git show-ref >/dev/null 2>&1
then
	echo 'error: not in a Git repository'
	exit 2
fi

if [ ! -f debian/changelog ]
then
	echo 'error: debian/changelog is not accessible'
	exit 2
fi

if git branch --show-current | grep -Eq 'main|master'
then
	echo 'error: please do not run me on a main branch'
	exit 2
fi

if ! dpkg-mergechangelogs --version >/dev/null 2>&1
then
	echo 'error: cannot find dpkg-mergechangelogs(1)'
	exit 2
fi

if ! git config --get merge.dpkg-mergechangelogs.driver | grep -q dpkg-mergechangelogs
then
	echo 'error: dpkg-mergechangelogs(1) is not configured as a Git merge driver'
	echo '(see the man page, section "INTEGRATION WITH GIT")'
	exit 2
fi

if ! git check-attr -a debian/changelog | grep -q dpkg-mergechangelogs
then
	echo 'error: debian/changelog is not configured to use the dpkg-mergechangelogs(1) Git merge driver'
	echo '(see the man page, section "INTEGRATION WITH GIT")'
	exit 2
fi

dchn=debian/changelog.next
if [ -f $dchn ]
then
	if test ! -s $dchn
	then
		echo "error: $dchn is empty"
		exit 2
	fi
	if grep -vq '\S' $dchn
	then
		echo "error: $dchn has blank lines"
		exit 2
	fi
	if grep -Evq '^(  \* | {4}| {4}- | {6})\S' $dchn
	then
		echo "error: $dchn is not properly formatted"
		exit 2
	fi
	if grep -q '\s$' $dchn
	then
		echo "error: $dchn has trailing whitespace"
		exit 2
	fi
	if grep -Eq '.{79}' $dchn
	then
		echo "error: $dchn has overly long lines"
		exit 2
	fi
fi

run()
{
	(set -x; "$@") 2>&1
}

run git log -1 --oneline

did_merge=yes
urgency=

if git merge-base --is-ancestor $from_branch HEAD
then
	echo "Changes from \"$from_branch\" are already merged into HEAD."
	did_merge=no

	if [ ! -f debian/changelog.next ]
	then
		echo 'No pending release-worthy changes found.'
		exit 4
	fi

	# Use previous value of Urgency: field
	urgency="--urgency $(dpkg-parsechangelog --show-field Urgency)"
else
	# Attempt (but do not yet commit) the merge
	if ! run git merge --no-commit --strategy-option=ours $from_branch
	then
		run git merge --abort
		exit 1
	fi
fi

#
# Run script with extra merge steps if present
#

if [ -f .merge.extra.sh ]
then
	. .merge.extra.sh </dev/null
fi

#
# Update changelog with new version, codename, and maintainer
#

if [ $did_merge = yes ]
then
	sed -i '1s/ unstable;/ UNRELEASED;/' debian/changelog
fi

if [ -f debian/changelog.next ]
then
	run debchange \
		--local $rel_suffix \
		--distribution $rel_codename \
		$urgency \
		'<<MERGE_BRANCH_PLACEHOLDER>>'

	if [ $did_merge = yes ]
	then
		echo '---- Changelog supplement ----'
	else
		echo '--------- Changelog ----------'
	fi
	cat debian/changelog.next
	echo '------------------------------'

	sed -i \
		-e '/<<MERGE_BRANCH_PLACEHOLDER>>/{r debian/changelog.next' \
		-e 'd}' \
		debian/changelog

	git rm --force debian/changelog.next \
	|| rm -fv debian/changelog.next
else
	run debchange \
		--local $rel_suffix \
		--distribution $rel_codename \
		$urgency \
		''
fi

git add debian/changelog

#
# Commit the merge
#

version=$(dpkg-parsechangelog --show-field Version)
msg="Release $version"

if [ -n "$MERGE_COMMIT_DATE" ]
then
	date=$(date -d "$MERGE_COMMIT_DATE" -R) || exit
	export GIT_AUTHOR_DATE=$date
	export GIT_COMMITTER_DATE=$date
fi

run git commit -m "$msg"

exit 0



# ???
#tag=$(echo "$version" | tr '~' _)
#  (set -x; git tag -a "$tag" -m "$message")



# end merge-release.sh
