#!/bin/bash
# secure-wrap.sh
#
# Script to allow external use of the secure_wrap() function
#

set -e

dir=$(cd $(dirname $0) && pwd)

. $dir/functions.sh

secure_wrap "$@"

# end secure-wrap.sh
