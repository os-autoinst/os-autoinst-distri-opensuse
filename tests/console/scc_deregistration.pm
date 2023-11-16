# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration "scc_deregistration";
use serial_terminal 'select_serial_terminal';

sub run {
    return unless (get_var('SCC_REGISTER') || get_var('HDD_SCC_REGISTERED'));

    select_serial_terminal;
    scc_deregistration;
}

1;
