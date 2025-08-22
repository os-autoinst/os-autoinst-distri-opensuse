# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: KTAP post-processing default parser
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::main;

use testapi;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless({}, $class);
}

=head2 parse_line

 parse_line($string);

Although each test (i.e. the ones listed in kselftest-list.txt) in a
collection (e.g. 'bpf', 'net' or 'livepatch') is required to output
valid KTAP output (lines starting with "ok" or "not ok"), they can
have several subtests which are not required to do so.

This poses a problem since we rely on the KTAP parser to show the results
in a nice way within openQA, because there is no guarantee about their
output format. Therefore, for each subtest that we might want to provide
KTAP output to, a specific strategy might be deployed within the 'parsers'
subpackage.

Each specific parse_line() implementation is responsible of processing a
string found in the subtest output and returning valid KTAP if applicable,
returning 'undef' otherwise. The default simply returns the same input,
so the post_process subroutine might be unable to check for known issues.

=cut

sub parse_line {
    my ($self, $string) = @_;
    return $string;
}

1;
