# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: Lemon <leli@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration "scc_deregistration";

sub run {
    return unless (get_var('SCC_REGISTER') || get_var('HDD_SCC_REGISTERED'));

    select_console 'root-console';
    scc_deregistration;
}

1;
