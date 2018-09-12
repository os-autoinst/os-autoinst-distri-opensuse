# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Enable kdump and verify it's enabled
# Maintainer: Yong Sun <yosun@suse.com>
package enable_kdump;

use strict;
use 5.018;
use warnings;
use base 'opensusebasetest';
use utils 'zypper_call';
use power_action_utils 'power_action';
use serial_terminal 'select_virtio_console';
use kdump_utils;
use testapi;

sub run {
    my $self = shift;
    select_console('root-console');

    # Also panic when softlockup
    # workaround bsc#1104778, skip s390x in 12SP4
    assert_script_run('echo "kernel.softlockup_panic = 1" >> /etc/sysctl.conf');
    my $output = script_output('sysctl -p', 10, proceed_on_failure => 1);
    unless ($output =~ /kernel.softlockup_panic = 1/) {
        record_soft_failure 'bsc#1104778';
    }

    # Activate kdump
    prepare_for_kdump;
    activate_kdump;

    # Reboot
    power_action('reboot');
    $self->wait_boot;
    select_console('root-console');
    die "Failed to enable kdump" unless kdump_is_active;
}

sub test_flags {
    return {fatal => 1};
}

1;
