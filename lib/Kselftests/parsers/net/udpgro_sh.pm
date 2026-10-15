# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:udpgro.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::udpgro_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test (and udpgro_fwd.sh, veth.sh) print a description padded
with 'printf', then append the status on the same line, e.g.:

  #  no GRO                                  ok
  # UDP fwd perf                             skip - needed 2 CPUs found 1

Lines that do not match this format are returned unchanged. A skip
status is left untouched rather than converted (see net.pm).

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*(\S.*?)\s{2,}(ok|failed|fail\b.*|skip\b.*)$/i) {
        my ($description, $st) = ($1, $2);
        return $test_ln if $st =~ /^skip\b/i;
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st =~ /^ok$/i;
        # failed / fail ...
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
