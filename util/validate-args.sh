#!/bin/sh
# validate-args.sh
#
# Check all environment variables whose name starts with "ARG_".
#

set -e

perl -C0 \
	-e '$| = 1;' \
	-e 'foreach my $var (sort(keys(%ENV))) {' \
	-e '  $var =~ /^ARG_/ or next;' \
	-e '  print("$var: ");' \
	-e '  $ENV{$var} =~ /^(\w[-+.~\w]{,63})?$/ or die "FAILED\n";' \
	-e '  print("OK\n");' \
	-e '}' \
2>&1

echo '==== All good ===='

# end validate-args.sh
