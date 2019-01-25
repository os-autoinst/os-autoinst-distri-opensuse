# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST logic on Network Restart while no config changes were made
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>
# Tags: fate#318787 poo#11450

package y2lan_restart_common;

use strict;
use Exporter 'import';
use testapi;
use utils 'systemctl';
use version_utils qw(is_sle is_leap);
use y2_common 'accept_warning_network_manager_default';

our @EXPORT = qw(
  check_etc_hosts_update
  close_network_settings
  check_network_status
  initialize_y2lan
  open_network_settings
  validate_etc_hosts_entry
  verify_network_configuration
);

sub initialize_y2lan {
    select_console 'x11';
    x11_start_program("xterm -geometry 155x50+5+5", target_match => 'xterm');
    become_root;
    # make sure that firewalld is stopped, or we have later pops for firewall activation warning
    # or timeout for command 'ip a' later
    if ((is_sle('15+') or is_leap('15.0+')) and script_run("systemctl show -p ActiveState firewalld.service | grep ActiveState=inactive")) {
        systemctl 'stop firewalld';
        assert_script_run("systemctl show -p ActiveState firewalld.service | grep ActiveState=inactive");
    }
    # enable debug for detailed messages and easier detection of restart
    assert_script_run 'sed -i \'s/DEBUG="no"/DEBUG="yes"/\' /etc/sysconfig/network/config';
    type_string "journalctl -f|egrep -i --line-buffered 'shutting down|ifdown all' > journal.log &\n";
    assert_script_run '> journal.log';    # clear journal.log
}

sub open_network_settings {
    type_string "yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev\n";
    accept_warning_network_manager_default;
    assert_screen 'yast2_lan', 180;       # yast2 lan overview tab
    send_key 'home';                      # select first device
    wait_still_screen 1, 1;
}

sub close_network_settings {
    wait_still_screen 1, 1;
    send_key 'alt-o';
    # new: warning pops up for firewall, alt-y for assign it to zone
    if (!wait_serial("yast2-lan-status-0", 180)) {
        check_screen([qw(yast2-lan-restart_firewall_active_warning yast2_lan_packages_need_to_be_installed)], 0);
        if (match_has_tag 'yast2-lan-restart_firewall_active_warning') {
            send_key 'alt-y';
            wait_still_screen 1, 1;
            send_key 'alt-n';
            wait_still_screen 1, 1;
            send_key 'alt-o';
        }
        elsif (match_has_tag 'yast2_lan_packages_need_to_be_installed') {
            send_key 'alt-i';
        }
        wait_serial("yast2-lan-status-0", 180) || die "'yast2 lan' didn't finish or exited with non-zero code";
    }

    type_string "\n\n";    # make space for better readability of the console
}

sub check_network_status {
    my ($expected_status, $device) = @_;
    $expected_status //= 'no_restart';
    assert_screen 'yast2_closed_xterm_visible';
    assert_script_run 'ip a';
    if ($device eq 'bond') {
        record_soft_failure 'bsc#992113';
    }
    else {
        assert_script_run 'dig suse.com|grep \'status: NOERROR\'';    # test if conection and DNS is working
    }
    assert_script_run 'cat journal.log';                              # print journal.log
    if ($expected_status eq 'restart') {
        assert_script_run '[ -s journal.log ]';                       # journal.log size is greater than zero (network restarted)
    }

    assert_script_run '> journal.log';                                # clear journal.log
    type_string "\n\n";                                               # make space for better readability of the console
}

sub verify_network_configuration {
    my ($fn, $dev_name, $expected_status, $workaround, $no_network_check) = @_;
    open_network_settings;

    $fn->($dev_name) if $fn;                                          # verify specific action

    close_network_settings;
    check_network_status($expected_status, $workaround) unless defined $no_network_check;
}

sub validate_etc_hosts_entry {
    my (%args) = @_;

    script_run("egrep \"@{[$args{ip}]}\\s@{[$args{fqdn}]}\\s@{[$args{host}]}\" /etc/hosts", 30)
      && record_soft_failure "bsc#1115644 Expected entry:\n \"@{[$args{ip}]}    @{[$args{fqdn}]} @{[$args{host}]}\" was not found in /etc/hosts";
    script_run "cat /etc/hosts";
}

sub set_network {
    my (%args) = @_;

    open_network_settings;
    send_key 'alt-i';    # edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if ($args{static}) {
        send_key 'alt-t';    # set to static ip
        assert_screen 'yast2_lan_static_ip_selected';
        send_key 'tab';
        if ($args{ip}) {     # To spare time, no update what to is already filled from previous run
            send_key_until_needlematch('ip_textfield_empty', 'backspace');    # delete existing IP if any
            type_string $args{ip};
        }
        send_key 'tab';
        if ($args{mask}) {                                                    # To spare time, no update what to is already filled from previous run
            send_key_until_needlematch('mask_textfield_empty', 'backspace');    # delete existing netmask if any
            type_string $args{mask};
        }
        send_key 'tab';
        send_key_until_needlematch('hostname_textfield_empty', 'backspace');
        type_string $args{fqdn};
        assert_screen 'yast2_lan_static_ip_set';
    }
    else {
        send_key 'alt-y';                                                       # set back to DHCP
        assert_screen 'yast2_lan_dhcp_set';
    }
    # Exit
    send_key 'alt-n';
    assert_screen "yast2_lan";
    close_network_settings;
}


=head2 check_etc_hosts_update

In order to target bugs bsc#1115644 and bsc#1052042, we want to :
- Set static IP and fqdn for first NIC in the list and check /etc/hosts formatting
- Open yast2 lan again and change the fqdn, check if /etc/hosts is changed correctly ( bsc#1052042 )
- Set it to DHCP
- Set it again to static with  new FQDN and check if /etc/hosts is changed correctly ( bsc#1115644 )
=cut
sub check_etc_hosts_update {

    my $ip   = '192.168.122.10';
    my $mask = '255.255.255.0';
    script_run "cat /etc/hosts";

    record_info 'Test', 'Set static ip, FQDN and validate /etc/hosts entry';
    my $hostname = "test-1";
    my $fqdn     = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    record_info 'Test', 'Change FQDN and validate /etc/hosts entry';
    $hostname = "test-2";
    $fqdn     = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    # Set back to dhcp
    set_network(fqdn => $fqdn);

    record_info 'Test', 'Set to static from dchp, set FQDN and validate /etc/hosts entry';
    $hostname = "test-3";
    $fqdn     = $hostname . '.susetest.com';
    set_network(static => 1, fqdn => $fqdn, ip => $ip, mask => $mask);
    validate_etc_hosts_entry(ip => $ip, host => $hostname, fqdn => $fqdn);

    # Set back to dhcp
    set_network;
}

1;
