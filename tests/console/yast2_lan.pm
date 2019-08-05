# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: yast2 lan functionality test https://bugzilla.novell.com/show_bug.cgi?id=600576
# - Install yast2-network
# - Launch yast2 lan
# - Return if handled by network manager
# - Handle firewall install screen and dhcp popups
# - Set domain (zq1.de) and hostname (system var, or "susetest")
# - Optionally, set ip, mask, hostname and check if /etc/hosts reflects the changes
# - Get system ip and hostname
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2_module_consoletest";

use strict;
use warnings;
use testapi;
use utils;
use y2lan_restart_common;
use version_utils ':VERSION';

my $module_name;

sub handle_Networkmanager_controlled {
    assert_screen "Networkmanager_controlled";
    send_key "ret";    # confirm networkmanager popup
    assert_screen "Networkmanager_controlled-approved";
    send_key "alt-c";
    if (check_screen('yast2-lan-really', 3)) {
        # SLED11...
        send_key 'alt-y';
    }
    wait_serial("$module_name-0", 60) || die "'yast2 lan' didn't finish";
}

sub handle_dhcp_popup {
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
    }
}

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call "in yast2-network";    # make sure yast2 lan module installed

    # those two are for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

    my $is_nm = !script_run('systemctl is-active NetworkManager');    # Revert boolean because of bash vs perl's return code.

    $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'lan');

    if ($is_nm) {
        handle_Networkmanager_controlled;
        return;                                                       # don't change any settings
    }

    assert_screen [qw(yast2_lan install-susefirewall2 install-firewalld dhcp-popup)], 120;
    handle_dhcp_popup;

    if (match_has_tag('install-susefirewall2') || match_has_tag('install-firewalld')) {
        # install firewall
        send_key "alt-i";
        # check yast2_lan again after firewall is installed
        assert_screen('yast2_lan', 90);
    }

    my $hostname = get_var('HOSTNAME', 'susetest');
    my $domain   = "zq1.de";

    send_key "alt-s";    # open hostname tab
    assert_screen [qw(yast2_lan-hostname-tab dhcp-popup)];
    handle_dhcp_popup;
    send_key "tab";
    for (1 .. 15) { send_key "backspace" }
    type_string $hostname;

    # Starting from SLE 15 SP1, we don't have domain field
    if (is_sle('<=15') || is_leap('<=15.0')) {
        send_key "tab";
        for (1 .. 15) { send_key "backspace" }
        type_string $domain;
    }

    assert_screen 'test-yast2_lan-1';
    send_key "alt-o";    # OK=>Save&Exit
    wait_serial("yast2-lan-status-0", 180) || die "'yast2 lan' didn't finish";
    wait_still_screen;

    # Run detailed check only if explicitly configured in the test suite
    check_etc_hosts_update() if get_var('VALIDATE_ETC_HOSTS');

    $self->clear_and_verify_console;
    assert_script_run "hostname|grep $hostname";

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;
