# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Default parser for the net collection
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

Most of the net selftests share the log_test_result() helper from
net/lib.sh, which prints one line per subtest, for example:

  # TEST: IPv4 packets over UDPv4                                       [ OK ]
  #     TEST: rule6 check: oif redirect to table                        [ OK ]

This is used as the default parser for the whole 'net' collection, so
every test relying on this helper (e.g. 'bareudp.sh', 'pmtu.sh' or
'fib_rule_tests.sh') gets valid KTAP subtest results without needing an
individual parser.

A few older scripts (e.g. 'rtnetlink.sh' or 'netdevice.sh') use their
own, simpler log_test(), printing lines such as:

  # PASS: bridge setup
  # FAIL: bridge_parent_id
  # XFAIL: veth0: ethtool dump not supported

These are recognized as well. Lines that do not match either format
are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    my ($description, $st);
    if ($ln =~ /^#\s*TEST:\s+(.*?)\s+\[\s*(OK|PASS|FAIL|SKIP|XFAIL|XPASS|ERROR)\s*\]$/i) {
        ($description, $st) = ($1, uc $2);
    } elsif ($ln =~ /^#\s*(OK|PASS|FAIL|SKIP|XFAIL|XPASS|ERROR):\s+(.*)$/i) {
        ($description, $st) = ($2, uc $1);
    } else {
        return $test_ln;
    }
    return $test_ln if $st eq 'SKIP';

    my $idx = ++$self->{idx};
    if ($st eq 'OK' or $st eq 'PASS' or $st eq 'XPASS') {
        return "# ok $idx $description";
    } elsif ($st eq 'XFAIL') {
        return "# ok $idx $description # TODO Expected failure";
    }
    # FAIL / ERROR
    return "# not ok $idx $description";
}

1;
