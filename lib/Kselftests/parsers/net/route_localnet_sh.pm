# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:route_localnet.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::route_localnet_sh;

use base 'Kselftests::parsers::net::arp_ndisc_evict_nocarrier_sh';
use testapi;
use strict;
use warnings;

=head2 parse_line

route_localnet.sh uses the same 'run NAME test' / bare 'ok'|'failed'
idiom as arp_ndisc_evict_nocarrier.sh. See
Kselftests::parsers::net::arp_ndisc_evict_nocarrier_sh for the parser.

=cut

1;
