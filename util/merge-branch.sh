#!/bin/bash
# merge-branch.sh
#
# This script is used in the management of a Debian source package's Git
# repository (i.e. where the debian/ subdirectory contents are maintained).
#
# It specifically merges recent changes in the main branch (which usually
# targets Debian sid/unstable) into a branch for an alternate release of
# distribution (e.g. Debian stable, or some Ubuntu release). If the merge
# is successful, the script will commit the new version. If merge conflicts
# occur, the tree will be left ready for manual intervention.
#
# This should be run in the Git repo, with the target branch active.
#
# Usage: merge-branch FROM_BRANCH REL_CODENAME REL_SUFFIX
#
# * FROM_BRANCH: Merge in changes from this branch
# * REL_CODENAME: Release codename for target distribution
# * REL_SUFFIX: Suffix to add to the version string, minus the final digit
#
# Example: merge-branch main noble '~ubu2404u'
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

#
# Attempt (but do not yet commit) the merge
#

ok=yes
run git merge --no-commit $from_branch || ok=no

# Update changelog with new version, codename, and maintainer
sed -i '1s/ unstable;/ UNRELEASED;/' debian/changelog
if [ -f debian/changelog.next ]
then
	run debchange --local $rel_suffix --distribution $rel_codename '<<MERGE_BRANCH_PLACEHOLDER>>'
	echo '---- Changelog supplement ----'
	cat debian/changelog.next
	echo '------------------------------'
	sed -i \
		-e '/<<MERGE_BRANCH_PLACEHOLDER>>/{r debian/changelog.next' \
		-e 'd}' \
		debian/changelog

	git rm debian/changelog.next
else
	run debchange --local $rel_suffix --distribution $rel_codename ''
fi
git add debian/changelog

# Create file with (eventual) commit message
version=$(dpkg-parsechangelog --show-field Version)
echo "Release $version" > tmp.commit-msg.txt

if [ $ok != yes ]
then
	branch=$(git branch --show-current)
	echo ----------------
	echo "Version: $version"
	echo "Branch: $branch"
	echo 'Cannot commit; see tmp.commit-msg.txt for commit message'
	exit 1
fi

#
# Commit the merge
#

if [ -n "$MERGE_COMMIT_DATE" ]
then
	date=$(date -d "$MERGE_COMMIT_DATE" -R) || exit
	export GIT_AUTHOR_DATE=$date
	export GIT_COMMITTER_DATE=$date
fi

msg=$(cat tmp.commit-msg.txt)

run git commit -m "$msg"
rm tmp.commit-msg.txt


# ???
#tag=$(echo "$version" | tr '~' _)
#  (set -x; git tag -a "$tag" -m "$message")



# end merge-branch.sh
