# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deregister from the SUSE Customer Center
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use registration "scc_deregistration";

sub run {
    select_console 'root-console';
    scc_deregistration;
}

1;
