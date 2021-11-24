# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker
# Summary: Manage cluster at boot time
#          Disable pacemaker at boot if pacemaker is active, otherwise enable it.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'systemctl';

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    if (systemctl('-q is-active pacemaker', ignore_failure => 1)) {
        record_info("Enable cluster", "Cluster is enabled at boot");
        systemctl("enable pacemaker");
    }
    else {
        record_info("Disable cluster", "Cluster is disabled at boot");
        systemctl("disable pacemaker");
    }
}

1;
