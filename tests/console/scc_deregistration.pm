# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: Lemon <leli@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration qw(scc_deregistration cleanup_registration);

sub run {
    return unless (get_var('SCC_REGISTER') || get_var('HDD_SCC_REGISTERED'));

    select_console 'root-console';
    scc_deregistration;
    cleanup_registration;
}

1;
