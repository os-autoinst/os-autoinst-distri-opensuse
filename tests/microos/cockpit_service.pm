# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic check for cockpit service
# Maintainer: qa-c team <qa-c@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use transactional;
use utils qw(systemctl);
use mm_network qw(is_networkmanager);
use version_utils qw(is_microos is_sle_micro is_leap_micro is_alp);
use serial_terminal;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Install cockpit if needed, this is needed for DVD flavor where
    # Cockpit pattern is not selected during install
    my @pkgs = ();

    if (script_run('rpm -q cockpit') != 0) {
        record_info('TEST', 'Installing Cockpit...');
        push @pkgs, 'cockpit';
    }

    if (is_networkmanager) {
        if (script_run('rpm -q cockpit-networkmanager') != 0) {
            push @pkgs, 'cockpit-networkmanager';
        }
    } else {
        if (is_microos || is_alp || is_leap_micro('5.3+') || is_sle_micro('5.3+')) {
            die sprintf('NetworkManager should be used by %s %s', get_var('DISTRI'), get_var('VERSION'));
        }
        if (script_run('rpm -q cockpit-wicked') != 0) {
            push @pkgs, 'cockpit-wicked';
        }
    }


    unless (is_sle_micro('<5.2') || is_leap_micro('<5.2') || is_alp) {
        push @pkgs, qw(cockpit-machines cockpit-tukit);
    }

    if (@pkgs) {
        record_info('TEST', 'Installing Cockpit\'s Modules...');
        # In ALP, we need to refresh the metadata. poo#122029
        assert_script_run('zypper ref') if is_alp;
        trup_call("pkg install @pkgs", timeout => 480);
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
    assert_script_run('lsof -i :9090', fail_message => 'Port 9090 is not opened!');
    systemctl('is-active cockpit.service');
    record_info('status', script_output('systemctl status cockpit.service'));


    # Cockpit should survive a reboot. After reboot cockpit.socket should be
    # enabled, but the service is not active, we need to do a request as before
    record_info('TEST', 'Cockpit survives a reboot');
    process_reboot(trigger => 1);
    systemctl('is-enabled cockpit.socket');
    assert_script_run('curl http://localhost:9090', fail_message => 'Cannot fetch index page');
    systemctl('is-active cockpit.service');
    record_info('status', script_output('systemctl status cockpit.service'));
}

1;
