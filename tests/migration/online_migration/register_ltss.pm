# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Register the LTSS extension
# Used when we migrate from LTSS to another LTSS version
# Maintainer: Julien Adamek <jadamek@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use registration qw(add_suseconnect_product);
use zypper qw(wait_quit_zypper);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Make sure that nothing is using rpm for avoiding lock conflict
    wait_quit_zypper;

    my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));
    if (grep $_ eq 'ltss', @scc_addons) {
        my $os_sp_version = get_var("HDDVERSION");
        $os_sp_version =~ s/-/_/g;
        add_suseconnect_product("SLES-LTSS", undef, undef, "-r " . get_var("SCC_REGCODE_LTSS_$os_sp_version"), 300, 0);
    }
}

1;
