# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker
# Summary: Manage cluster at boot time
#          Disable pacemaker at boot if pacemaker is active, otherwise enable it.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';

sub run {
    select_serial_terminal;
    if (systemctl('-q is-active pacemaker', ignore_failure => 1)) {
        record_info("Enable cluster", "Cluster is enabled at boot");
        systemctl("enable pacemaker");
    }
    else {
        record_info("Disable cluster", "Cluster is disabled at boot");
        systemctl("disable pacemaker");
    }
}

sub post_run_hook {
    # this post_run is almost identical to the parent's post_run function
    # excluding the 'record_avc_selinux_alerts' call, which causes
    # needle failures due to unexpected console output
    my ($self) = @_;

    # start next test in home directory
    enter_cmd "cd";
    $self->clear_and_verify_console;
}

1;
