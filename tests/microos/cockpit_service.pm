# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic check for cockpit service
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional;
use utils qw(systemctl);
use mm_network qw(is_networkmanager);
use version_utils qw(is_microos is_sle_micro is_leap_micro is_alp);

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # Install cockpit if needed, this is needed for DVD flavor where
    # Cockpit pattern is not selected during install
    my @pkgs = ();

    if (script_run('rpm -q cockpit') != 0) {
        push @pkgs, 'cockpit';
    }

    record_info('Packages', script_output('zypper se -t package cockpit'));

    if (is_microos || is_alp) {
        push @pkgs, qw(
          cockpit-bridge
          cockpit-devel
          cockpit-doc
          cockpit-kdump
          cockpit-machines
          cockpit-networkmanager
          cockpit-packagekit
          cockpit-podman
          cockpit-storaged
          cockpit-system
          cockpit-tests
          cockpit-tukit
          cockpit-ws);
    } elsif (is_sle_micro || is_leap_micro) {
        push @pkgs, qw(
          cockpit-bridge
          cockpit-podman
          cockpit-system
          cockpit-ws);
        if (is_networkmanager && (script_run('rpm -q cockpit-networkmanager') != 0)) {
            push @pkgs, 'cockpit-networkmanager';
        } else {
            push @pkgs, 'cockpit-wicked';
        }
        if (is_sle_micro('=5.1')) {
            push @pkgs, 'cockpit-dashboard';
        } elsif (is_sle_micro('=5.2')) {
            push @pkgs, qw(cockpit-machines cockpit-tukit);
        } elsif (is_sle_micro('>=5.3')) {
            push @pkgs, qw(
              cockpit-kdump
              cockpit-machines
              cockpit-selinux
              cockpit-storaged
              cockpit-tukit);
        } elsif (is_leap_micro) {
            push @pkgs, 'cockpit-branding-openSUSE-Leap-Micro';
        }
    }

    if (@pkgs) {
        record_info('Install', "Installing Cockpit Packages:\n@pkgs");
        trup_call("pkg install @pkgs", timeout => 300);
        check_reboot_changes;
    }

    record_info('Cockpit', script_output('rpm -qi cockpit'));

    # Enable cockpit
    #   By enabling the socket, the service shall remain inactive. We can either
    #   start the service manually or wait to have an http request where it will
    #   be activated automatically
    record_info('Service', "Enable Cockpit service and check it's active and accessible on http://localhost:9090");
    systemctl('enable --now cockpit.socket');
    systemctl('is-enabled cockpit.socket');
    systemctl('is-active cockpit.service', expect_false => 1);
    assert_script_run('curl http://localhost:9090', fail_message => 'Cannot fetch index page');
    assert_script_run('lsof -i :9090', fail_message => 'Port 9090 is not opened!');
    systemctl('is-active cockpit.service');
    record_info('Status', script_output('systemctl status cockpit.service'));


    # Cockpit should survive a reboot. After reboot cockpit.socket should be
    # enabled, but the service is not active, we need to do a request as before
    record_info('Reboot', 'Test that Cockpit survives a reboot.');
    process_reboot(trigger => 1);
    systemctl('is-enabled cockpit.socket');
    assert_script_run('curl http://localhost:9090', fail_message => 'Cannot fetch index page');
    systemctl('is-active cockpit.service');
    record_info('Status', script_output('systemctl status cockpit.service'));
}

1;
