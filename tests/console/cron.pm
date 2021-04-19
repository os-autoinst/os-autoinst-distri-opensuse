# Copyright (C) 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: cronie
# Summary: Check for CRON daemon
# - check if cron is enabled
# - check if cron is active
# - check cron status
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # check if cronie is installed, enabled and running
    assert_script_run 'rpm -q cronie';
    systemctl 'is-enabled cron';
    systemctl 'is-active cron';
    systemctl 'status cron';
}

1;

