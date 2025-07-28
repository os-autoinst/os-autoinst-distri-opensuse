# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker-cli
# Summary: Check cluster integrity
# Maintainer: QE-SAP <qe-sap@suse.de>, Christian Lanig <clanig@suse.com>

use base 'haclusterbasetest';
use testapi;
use hacluster;

sub run {
    select_console 'root-console';
    sleep 120;
    # Check for the state of the whole cluster
    check_cluster_state;
}

1;
