# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration "scc_deregistration";

sub run {
    select_console 'root-console';
    scc_deregistration;
}

1;
