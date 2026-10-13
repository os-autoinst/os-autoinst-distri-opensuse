# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Parser for the net:test_vxlan_fdb_changelink.sh selftest
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::parsers::net::test_vxlan_fdb_changelink_sh;

use base 'Kselftests::parsers::net::test_vxlan_under_vrf_sh';
use testapi;
use strict;
use warnings;

=head2 parse_line

The SLE 16.0 version of this test uses the same 'echo -n' followed by
a bracketed status on the same line as test_vxlan_under_vrf.sh, e.g.:

  # expected two remotes after fdb append	[ OK ]

See Kselftests::parsers::net::test_vxlan_under_vrf_sh for the parser.

=cut

1;
