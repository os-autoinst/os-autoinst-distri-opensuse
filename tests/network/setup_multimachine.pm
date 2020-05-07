# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test preparing the static IP and hostname for simple multimachine tests
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils 'zypper_call';
use Utils::Systemd 'disable_and_stop_service';
use version_utils qw(is_sle is_opensuse);

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    select_console 'root-console';

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall);
    #disable apparmor
    script_run("systemctl disable apparmor.service");
    script_run("systemctl stop apparmor.service");

    # Configure the internal network an  try it
    if ($hostname =~ /server|master/) {
        setup_static_mm_network('10.0.2.101/24');
        #if server running opensuse.
        if (is_opensuse) {
            assert_script_run 'systemctl stop NetworkManager';
            assert_script_run 'systemctl disable NetworkManager';
            assert_script_run 'systemctl start  wicked';
        }
    }
    else {
        setup_static_mm_network('10.0.2.102/24');

        my $base_product = get_var('SLE_PRODUCT');
        if ($base_product eq "sled") {
            if (is_sle('=15')) {
                assert_script_run 'systemctl restart  wicked';
            }
            else {
                assert_script_run 'systemctl stop NetworkManager';
                assert_script_run 'systemctl disable NetworkManager';
                assert_script_run 'systemctl enable wicked';
                assert_script_run 'systemctl start  wicked';
            }
        }
        #Opensuse versions
        if (is_opensuse) {
            assert_script_run 'systemctl stop NetworkManager';
            assert_script_run 'systemctl disable NetworkManager';
            assert_script_run 'systemctl start  wicked';
        }
    }

    # Set the hostname to identify both minions
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname|grep $hostname";
}

1;

