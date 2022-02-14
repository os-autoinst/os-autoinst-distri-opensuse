# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test preparing the static IP and hostname for simple multimachine tests
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(zypper_call permit_root_ssh);
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);
use version_utils qw(is_sle is_opensuse);

sub is_networkmanager {
    return (script_run('readlink /etc/systemd/system/network.service | grep NetworkManager') == 0);
}

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    my ($nm_id, $device);
    select_console 'root-console';
    if (is_networkmanager) {
        $nm_id = script_output('nmcli -t -f NAME c');
        $device = script_output('nmcli -t -f DEVICE c');
    }

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);

    # Configure the internal network an  try it
    if ($hostname =~ /server|master/) {
        setup_static_mm_network('10.0.2.101/24');

        if (is_networkmanager) {
            assert_script_run "nmcli connection modify '$nm_id' ifname '$device' ip4 '10.0.2.101/24' gw4 10.0.2.2 ipv4.method manual ";
            assert_script_run "nmcli connection down '$nm_id'";
            assert_script_run "nmcli connection up '$nm_id'";
        }
        else {
            assert_script_run 'systemctl restart  wicked';
        }
    }
    else {
        setup_static_mm_network('10.0.2.102/24');

        if (is_networkmanager) {
            assert_script_run "nmcli connection modify '$nm_id' ifname '$device' ip4 '10.0.2.102/24' gw4 10.0.2.2 ipv4.method manual ";
            assert_script_run "nmcli connection down '$nm_id'";
            assert_script_run "nmcli connection up '$nm_id'";
        }
        else {
            systemctl("restart wicked");
        }
    }

    # Set the hostname to identify both minions
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname|grep $hostname";

    # Make sure that PermitRootLogin is set to yes
    # This is needed only when the new SSH config directory exists
    # See: poo#93850
    permit_root_ssh();
}

1;

