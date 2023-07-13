# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Package: yast2-network hostname iproute2
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
use Utils::Backends 'is_pvm_hmc';

my $module_name;

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call "in yast2-network";    # make sure yast2 lan module installed

    # those two are for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

    my $y2_opts = is_pvm_hmc() ? "ncurses" : "";
    my $opened = open_yast2_lan(ui => $y2_opts);
    wait_still_screen(14);
    if ($opened eq "Controlled by network manager") {
        return;
    }

    my $hostname = get_var('HOSTNAME', 'susetest');
    my $domain = "zq1.de";

    send_key "alt-s";    # open hostname tab
    assert_screen [qw(yast2_lan-hostname-tab dhcp-popup)];
    handle_dhcp_popup();
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

    # Do not set hostname via DHCP - poo#66775
    # This is already the default on SLE, so change it for openSUSE only
    if (is_opensuse) {
        send_key "tab";
        assert_screen 'yast2_lan-set-hostname-via-dhcp-selected';
        send_key 'down';
        send_key_until_needlematch("yast2_lan-set-hostname-via-dhcp-NO-selected", "up", 6);
        send_key "ret";
    }

    close_yast2_lan;
    wait_still_screen;

    # Run detailed check only if explicitly configured in the test suite
    check_etc_hosts_update() if get_var('VALIDATE_ETC_HOSTS');

    $self->clear_and_verify_console;
    assert_script_run "hostnamectl --static |grep $hostname";

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;
