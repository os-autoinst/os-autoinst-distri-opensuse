# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller/master for remote installations
# Tags: poo#9576
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use testapi;
use utils;
use mm_network;
use lockapi;
use mmapi;

sub run {
    my $target_ip;
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    my $password = 'nots3cr3t';

    mutex_lock("installation_ready", $child_id);

    # Wait until target becomes ready
    # parse dhcpd.leases - now it should contain entries for all nodes
    my %dhcp_leases;
    my $dhcp_leases_file = script_output("cat /var/lib/dhcp/db/dhcpd.leases\n");
    my $lease_ip;

    for my $line (split /\n/, $dhcp_leases_file) {
        if ($line =~ /^lease\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
            (undef, $lease_ip) = split(/\s/, $line);
        }
        elsif ($line =~ /client-hostname\s+"(.*)"/) {
            my $hostname = lc($1);
            $dhcp_leases{$hostname} //= [];
            push(@{$dhcp_leases{$hostname}}, $lease_ip);
        }
    }

    mutex_unlock("installation_ready", $child_id);
    ensure_serialdev_permissions;

    if (check_var("REMOTE_CONTROLLER", "vnc")) {
        select_console 'x11';
        x11_start_program('xterm');
        enter_cmd "vncviewer -fullscreen $lease_ip:1";
        # wait for password prompt
        assert_screen "remote_master_password";
        enter_cmd "$password";
    }
    elsif (check_var("REMOTE_CONTROLLER", "ssh")) {
        set_var 'TARGET_IP', $lease_ip;
        set_var 'PASSWD', $password;
        select_console 'user-console';
        clear_console;
        enter_cmd "ssh root\@$lease_ip";
        assert_screen "remote-ssh-login";
        enter_cmd "yes";
        assert_screen 'password-prompt';
        enter_cmd "$password";
        assert_screen "remote-ssh-login-ok";
        enter_cmd "yast.ssh";
    }
    else {
        die("REMOTE_CONTROLLER has wrong value");
    }
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
