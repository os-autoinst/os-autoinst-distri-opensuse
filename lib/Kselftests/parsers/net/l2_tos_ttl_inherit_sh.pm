# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:l2_tos_ttl_inherit.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::l2_tos_ttl_inherit_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=encoding UTF-8

=head2 parse_line

 parse_line($string);

This test prints a box-drawn table, one row per case, with the result
in the last column, e.g.:

  │    gre │     4 │     4 │ inherit 0x08 │  inherit 134 │ false │     OK │

Table headers and separator lines don't have 'OK'/'FAIL' in the last
column and are returned unchanged, same as the extra diagnostic rows
printed below a failing row. This module is saved as UTF-8 without
'use utf8', so the box-drawing character below is matched as its raw
byte sequence, same as the unencoded log lines coming from
Kselftests::utils::post_process_single().

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;

    if ($ln =~ /^#\s*│\s*(\S+)\s*│\s*(\S+)\s*│\s*(\S+)\s*│\s*([^│]+?)\s*│\s*([^│]+?)\s*│\s*(\S+)\s*│\s*(OK|FAIL)\s*│$/) {
        my ($type, $outer, $inner, $tos, $ttl, $vlan, $st) = ($1, $2, $3, $4, $5, $6, uc $7);
        my $description = "$type $outer->$inner tos=$tos ttl=$ttl vlan=$vlan";
        my $idx = ++$self->{idx};
        return "# ok $idx $description" if $st eq 'OK';
        return "# not ok $idx $description";
    }
    return $test_ln;
}

1;
