#!/bin/bash
# secure-wrap.sh
#
# Wrapper script that limits a command's read-write access, hides a few
# sensitive areas, and cuts off network access.
#

addl_bind_list=

# Directories to hide altogether (sensitive material)
#
for dir in \
	$HOME/.gnupg \
	$HOME/.ssh \
	$XDG_RUNTIME_DIR \
	$SECURE_WRAP_HIDE_DIRS
do
	test ! -d $dir || addl_bind_list+=" --tmpfs $dir"
done

# Allow read/write access to these directories
#
for dir in $SECURE_WRAP_RW_DIRS
do
	test ! -d $dir || addl_bind_list+=" --bind $dir $(realpath $dir)"
done

echo + "$@" >&2

exec bwrap \
	--ro-bind / / \
	--dev /dev \
	--tmpfs /tmp \
	--unshare-net \
	$addl_bind_list \
	"$@"

# end secure-wrap.sh
