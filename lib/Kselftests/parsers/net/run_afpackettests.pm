# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:run_afpackettests selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::run_afpackettests;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

run_afpackettests (and run_netsocktests) announce a subtest with
'echo "running NAME test"', then run the test binary, whose own
verbose output comes in between, and finally print the bracketed
status alone on its own line once the binary exits, e.g.:

  # running psock_fanout test
  # --------------------
  # ... (output from the psock_fanout binary) ...
  # [PASS]

The subtest name from the last 'running ... test' line is kept and
used once the bracketed status line shows up. A SKIP status is left
untouched rather than converted (see net.pm).

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*running\s+(.*?)\s+test\s*$/i) {
        $self->{pending} = $1;
        return $test_ln;
    }
    if ($ln =~ /^#\s*\[\s*(OK|PASS|FAIL|SKIP|XFAIL|XPASS|ERROR)\s*\]\s*$/i) {
        my $st = uc $1;
        return $test_ln if $st eq 'SKIP';
        my $description = delete $self->{pending} // 'result';
        my $idx = ++$self->{idx};
        if ($st eq 'OK' or $st eq 'PASS' or $st eq 'XPASS') {
            return "# ok $idx $description";
        } elsif ($st eq 'XFAIL') {
            return "# ok $idx $description # TODO Expected failure";
        }
        # FAIL / ERROR
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
