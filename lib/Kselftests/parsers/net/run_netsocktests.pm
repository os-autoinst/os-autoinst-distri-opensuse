# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:run_netsocktests selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::run_netsocktests;

use base 'Kselftests::parsers::net::run_afpackettests';
use testapi;
use strict;
use warnings;

=head2 parse_line

run_netsocktests uses the same 'running NAME test' / bracketed status
idiom as run_afpackettests. See
Kselftests::parsers::net::run_afpackettests for the parser.

=cut

1;
