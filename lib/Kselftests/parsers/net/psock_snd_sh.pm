# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:psock_snd.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::psock_snd_sh;

use base 'Kselftests::parsers::main';
use testapi;
use strict;
use warnings;

=head2 parse_line

 parse_line($string);

This test echoes a description, then runs the psock_snd binary, whose
first action is always 'system("sysctl -w net.ipv4.conf.lo.accept_local=1")',
printing 'net.ipv4.conf.lo.accept_local = 1' before anything else, e.g.:

  # raw csum_off with bad offset (expected to fail)
  # net.ipv4.conf.lo.accept_local = 1
  # ./psock_snd: write: Invalid argument
  # raw min size
  # net.ipv4.conf.lo.accept_local = 1
  # tx: 42
  # rx: 0
  # OK

Cases labelled '(expected to fail)' are wrapped in '(! cmd)' by the
script and print no 'OK'; the script uses 'set -e' otherwise, so
reaching the next case's sysctl line (or the closing
'OK. All tests passed') proves the previous one behaved as expected.
The description is therefore resolved one case late, when its
successor starts. An actual, unexpected failure aborts the script and
leaves the last case unresolved. Lines that do not match this format
are returned unchanged.

=cut

sub parse_line {
    my ($self, $test_ln) = @_;
    my $ln = $test_ln =~ s/\s+$//r;
    (my $content = $ln) =~ s/^#\s*//;

    if ($content eq 'net.ipv4.conf.lo.accept_local = 1') {
        my $result;
        if (defined $self->{header}) {
            my $idx = ++$self->{idx};
            $result = "# ok $idx $self->{header}";
        }
        $self->{header} = $self->{prev};
        return $result;
    }
    if ($content =~ /^OK\.\s*All tests passed$/i) {
        if (defined $self->{header}) {
            my $idx = ++$self->{idx};
            my $r = "# ok $idx " . delete $self->{header};
            return $r;
        }
        return $test_ln;
    }
    $self->{prev} = $content if length $content;
    return $test_ln;
}

1;
