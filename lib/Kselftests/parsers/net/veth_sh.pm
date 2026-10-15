# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:veth.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::veth_sh;

use base 'Kselftests::parsers::net::udpgro_sh';
use testapi;
use strict;
use warnings;

=head2 parse_line

veth.sh uses the same padded-description-then-status idiom as
udpgro.sh. See Kselftests::parsers::net::udpgro_sh for the parser.

=cut

1;
