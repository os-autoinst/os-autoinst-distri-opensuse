# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure software watchdog
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use lockapi;

sub run {
    # Configure the software watchdog
    script_run 'echo softdog > /etc/modules-load.d/softdog.conf';
    script_run 'systemctl restart systemd-modules-load.service';

    # Softdog module needs to be loaded
    assert_script_run 'lsmod | grep -q softdog';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
