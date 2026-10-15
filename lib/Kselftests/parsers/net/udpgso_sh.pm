# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:udpgso.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::udpgso_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test echoes a description, then runs the udpgso binary, which
prints one diagnostic line per internal case (some intentionally
marked '(fail)', meaning that specific case is expected to reject the
send) and a bare 'OK' once all of them behaved as expected, e.g.:

  # ipv4 cmsg
  # ipv4 tx:1 gso:0
  # ipv4 tx:1473 gso:0 (fail)
  # ...
  # OK

The script uses 'set -o errexit' and never wraps the binary call, so
any unexpected result aborts the script immediately; a bare 'OK' is
only ever reached when the whole case succeeded. The '(fail)' tag is
part of the diagnostic text, not a result, so lines starting with
'ipv4 tx:'/'ipv6 tx:' are not treated as a new description. Lines
that do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(ipv[46](?!\s+tx:).*)$/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*OK\s*$/i) {
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        return "# ok $idx $description";
    }
    return $test_ln;
}

1;
