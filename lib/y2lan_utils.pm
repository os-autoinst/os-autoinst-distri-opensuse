# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Useful subroutines for yast2_lan related test modules
# Maintainer: Veronika Svecova <vsvecova@suse.com>

package y2lan_utils;

use base "opensusebasetest";
use strict;
use warnings;
use utils;
use testapi;
use Exporter 'import';
use version_utils qw(is_sle is_leap);
use y2_common 'accept_warning_network_manager_default';

our @EXPORT = qw(
  open_yast2_lan_first_time
  open_yast2_lan_again
  close_yast2_lan
  handle_Networkmanager_controlled
  handle_dhcp_popup
  check_etc_hosts_update
  close_network_settings
  check_network_status
  initialize_y2lan
  open_network_settings
  validate_etc_hosts_entry
  verify_network_configuration
);

=head2 handle_Networkmanager_controlled

Confirms the network manager pop up and closes off yast2 lan.

=cut

sub handle_Networkmanager_controlled {
    send_key "ret";    # confirm networkmanager popup
    assert_screen "Networkmanager_controlled-approved";
    send_key "alt-c";
    if (check_screen('yast2-lan-really', 3)) {
        # SLED11...
        send_key 'alt-y';
    }
    wait_serial("yast2-lan-status-0", 60) || die "'yast2 lan' didn't finish";
}

=head2 handle_dhcp_popup

Closes DHCP pop up window when dhcp-popup needle is matched.

=cut

sub handle_dhcp_popup {
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
    }
}

=head2 open_yast2_lan_first_time

Opens yast2 lan and checks for DHCP, firewall and network manager pop ups. Installs firewall in case there is a requirement to do so.

To open yast2 lan again within the same module, open_yast2_lan_again should be used, as it skips the pop up checks that are only relevant the first time.

Requires a root console to be open first.

=cut

sub open_yast2_lan_first_time {
    script_run("yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev", 0);
    assert_screen [qw(Networkmanager_controlled yast2_lan install-susefirewall2 install-firewalld dhcp-popup)], 120;
    handle_dhcp_popup;
    if (match_has_tag('Networkmanager_controlled')) {
        handle_Networkmanager_controlled;
        return "Controlled by network manager";
    }
    if (match_has_tag('install-susefirewall2') || match_has_tag('install-firewalld')) {
        # install firewall
        send_key "alt-i";
        # check yast2_lan again after firewall is installed
        assert_screen [qw(Networkmanager_controlled yast2_lan)], 90;
        if (match_has_tag('Networkmanager_controlled')) {
            handle_Networkmanager_controlled;
            return "Controlled by network manager";
        }
    }
}

=head2 open_yast2_lan_again

Opens yast2 lan for second time or more within the same module.
Does not check for any pop ups, therefore it is advisable to use it after the pop ups have been handled, for example by open_yast2_lan_first_time.

Needs to be run in a root console.

=cut

sub open_yast2_lan_again {
    script_run("yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev", 0);
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;
}

=head2 close_yast2_lan

Closes yast2 lan.

=cut

sub close_yast2_lan {
    send_key "alt-o";    # OK=>Save&Exit
    wait_serial("yast2-lan-status-0", 180) || die "'yast2 lan' didn't finish";
    wait_still_screen;
    clear_console;
}

=head2 initialize_y2lan

Prepares the SUT for working with yast2 lan.

Disables firewall to avoid firewall pop ups and enables the debug setting in network config.

=cut

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

=head2 open_network_settings

Opens yast2 lan, selects the first available device and opens its settings.

=cut

sub open_network_settings {
    type_string "yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev\n";
    accept_warning_network_manager_default;
    assert_screen 'yast2_lan', 180;       # yast2 lan overview tab
    send_key 'home';                      # select first device
    wait_still_screen 1, 1;
}

=head2 close_network_settings

Closes yast2 lan and handles a firewall warning pop up, if applicable.

=cut

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

=head2 check_network_status

Checks that connection and DNS are working without issues on a selected $device.

=cut

sub check_network_status {
    my ($expected_status, $device) = @_;
    $expected_status //= 'no_restart';
    assert_screen 'yast2_closed_xterm_visible';
    assert_script_run 'ip a';
    if ($device eq 'bond') {
        record_soft_failure 'bsc#992113';
    }
    else {
        assert_script_run 'dig suse.com|grep \'status: NOERROR\'';    # test if connection and DNS is working
    }
    assert_script_run 'cat journal.log';                              # print journal.log
    if ($expected_status eq 'restart') {
        assert_script_run '[ -s journal.log ]';                       # journal.log size is greater than zero (network restarted)
    }

    assert_script_run '> journal.log';                                # clear journal.log
    type_string "\n\n";                                               # make space for better readability of the console
}

=head2 verify_network_configuration

Verifies that a specific defined action $fn is performed correctly on $device.

=cut

sub verify_network_configuration {
    my ($fn, $dev_name, $expected_status, $workaround, $no_network_check) = @_;
    open_network_settings;

    $fn->($dev_name) if $fn;    # verify specific action

    close_network_settings;
    check_network_status($expected_status, $workaround) unless defined $no_network_check;
}

=head2 validate_etc_hosts_entry

Verifies that a specific string is present in /etc/hosts.

=cut

sub validate_etc_hosts_entry {
    my (%args) = @_;

    script_run("egrep \"@{[$args{ip}]}\\s@{[$args{fqdn}]}\\s@{[$args{host}]}\" /etc/hosts", 30)
      && record_soft_failure "bsc#1115644 Expected entry:\n \"@{[$args{ip}]}    @{[$args{fqdn}]} @{[$args{host}]}\" was not found in /etc/hosts";
    script_run "cat /etc/hosts";
}

=head2 set_network

Opens yast2 lan, sets network according to defined settings and closes yast2 lan.
By default assigns networks settings to DHCP. Alternatively, it can be set to a specified static IP or mask.

=cut

sub set_network {
    my (%args) = @_;

    open_network_settings;
    send_key 'alt-i';    # edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if ($args{static}) {
        send_key 'alt-t';    # set to static ip
        assert_screen 'yast2_lan_static_ip_selected';
        send_key 'tab';
        if ($args{ip}) {     # To spare time, no update to what is already filled from previous run
            send_key_until_needlematch('ip_textfield_empty', 'backspace');    # delete existing IP if any
            type_string $args{ip};
        }
        send_key 'tab';
        if ($args{mask}) {                                                    # To spare time, no update to what is already filled from previous run
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
- Set it again to static with new FQDN and check if /etc/hosts is changed correctly ( bsc#1115644 )

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
