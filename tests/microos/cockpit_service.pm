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
        record_info('TEST', 'Installing Cockpit...');
        trup_call('pkg install cockpit');
        check_reboot_changes;
    }

    record_info('Cockpit', script_output('rpm -qi cockpit'));

    # Enable cockpit
    #   By enabling the socket, the service shall remain inactive. We can either
    #   start the service manually or wait to have an http request where it will
    #   be activated automatically
    record_info('TEST', "Cockpit is active and accessible on http://localhost:9090");
    systemctl('enable --now cockpit.socket');
    systemctl('is-enabled cockpit.socket');
    systemctl('is-active cockpit.service', expect_false => 1);
    assert_script_run('curl http://localhost:9090', fail_message => 'Cannot fetch index page');
    assert_script_run('lsof -i :9090',              fail_message => 'Port 9090 is not opened!');
    systemctl('is-active cockpit.service');


    # Cockpit should survive a reboot. After reboot cockpit.socket should be
    # enabled, but the service is not active, we need to do a request as before
    record_info('TEST', 'Cockpit survives a reboot');
    process_reboot(trigger => 1);
    systemctl('is-enabled cockpit.socket');
    assert_script_run('curl http://localhost:9090', fail_message => 'Cannot fetch index page');
    systemctl('is-active cockpit.service');
}

1;
