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

our @EXPORT_OK = qw(
  initialize_y2lan
  open_network_settings
  close_network_settings
  check_network_status
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
    type_string "yast2 lan\n";
    accept_warning_network_manager_default;
    assert_screen 'yast2_lan', 100;       # yast2 lan overview tab
    send_key 'home';                      # select first device
    wait_still_screen(2);
}

sub close_network_settings {
    wait_still_screen;
    send_key 'alt-o';
    # new: warning pops up for firewall, alt-y for assign it to zone
    assert_screen([qw(yast2-lan-restart_firewall_active_warning yast2_closed_xterm_visible yast2_lan_packages_need_to_be_installed)], 120);
    if (match_has_tag 'yast2-lan-restart_firewall_active_warning') {
        send_key 'alt-y';
        wait_still_screen 1;
        send_key 'alt-n';
        wait_still_screen 1;
        send_key 'alt-o';
    }
    elsif (match_has_tag 'yast2_lan_packages_need_to_be_installed') {
        send_key 'alt-i';
    }
    assert_screen 'yast2_closed_xterm_visible', 120;    # ensure coming back to root console
    type_string "\n\n";                                 # make space for better readability of the console
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
    elsif (is_sle('<15') || is_leap('<15.0')) {
        assert_script_run '[ ! -s journal.log ]';
    }
    assert_script_run '> journal.log';                                # clear journal.log
    type_string "\n\n";                                               # make space for better readability of the console
}

sub verify_network_configuration {
    my ($fn, $dev_name, $expected_status, $workaround) = @_;
    open_network_settings;

    $fn->($dev_name) if $fn;                                          # verify specific action

    close_network_settings;
    check_network_status($expected_status, $workaround);
}

1;
