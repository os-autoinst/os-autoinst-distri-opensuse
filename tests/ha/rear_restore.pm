# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rear23a
# Summary: Restore a ReaR backup
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'rear';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME', 'susetest');
    my $timeout = bmwqemu::scale_timeout(600);

    # Select recovering entry and wait for OS boot
    assert_screen('rear-boot-screen');
    send_key_until_needlematch('rear-recover-selected', 'up');
    send_key 'ret';
    $self->wait_boot_past_bootloader;

    # Restore the OS backup
    set_var('LIVETEST', 1);    # Because there is no password in ReaR miniOS
    select_console('root-console', skip_setterm => 1);    # Serial console is not configured in ReaR miniOS
    assert_script_run('export USER_INPUT_TIMEOUT=5; rear -d -D recover', timeout => $timeout);
    $self->upload_rear_logs;
    set_var('LIVETEST', 0);

    # Reboot into the restored OS
    power_action('reboot', keepconsole => 1);
    $self->wait_boot;

    # Test login to ensure that the based OS configuration is correctly restored
    select_serial_terminal;
    assert_script_run('cat /etc/os-release ; uname -a');
}

1;
