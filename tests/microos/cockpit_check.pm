# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic check for cockpit service
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional;
use utils qw(systemctl);

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # Install cockpit if needed, this is needed for DVD flavor where
    # Cockpit pattern is not selected during install
    if (script_run('rpm -q cockpit') != 0) {
        record_info('INFO', 'Installing Cockpit...');
        trup_call 'pkg install cockpit';
        check_reboot_changes;
    }

    record_info('Cockpit', script_output('rpm -qi cockpit'));

    # Enable service
    systemctl 'enable --now cockpit.socket';
    systemctl 'start cockpit';
    systemctl 'is-enabled cockpit';
    record_info('INFO', "Cockpit is enabled, let's reboot");

    # Cockpit should survive a reboot
    process_reboot(trigger => 1);
    systemctl 'is-enabled cockpit';
    record_info('INFO', 'Cockpit is enabled after reboot');

    # Check port 9090 where Cockpit UI is listening
    assert_script_run('lsof -i :9090', fail_message => 'Port 9090 is not opened!');
    record_info('INFO', 'Port 9090 is opened');
}

1;
