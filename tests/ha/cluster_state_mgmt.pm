# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Manage cluster stack
#          Stop the cluster if pacemaker is active, otherwise start it.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';

sub run {
    my $self = shift;
    select_serial_terminal;
    if (systemctl('-q is-active pacemaker', ignore_failure => 1)) {
        record_info("Start cluster", "Cluster is starting");
        script_run "crm cluster start";
    }
    else {
        record_info("Stop cluster", "Cluster is stopping");
        script_run "crm cluster stop", timeout => 300;
    }
}

1;
