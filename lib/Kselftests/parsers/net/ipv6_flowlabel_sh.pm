# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:ipv6_flowlabel.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::ipv6_flowlabel_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

ipv6_flowlabel.sh runs ipv6_flowlabel_mgr, whose __expect() macro
prints the status first, e.g.:

  # [OK]   flowlabel_get(fd, 1, 255, 0)

On failure it calls error(), which aborts the process after printing
'[ERR]  <expr> (line N)', optionally prefixed by the program name.
Lines that do not match this format are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(?:\S+:\s*)?\[(OK|ERR)\]\s+(\S.*)$/i) {
        my ($st, $description) = (uc $1, $2);
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'OK';
        # ERR
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
