# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
