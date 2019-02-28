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
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "console_yasttest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils ':VERSION';
use utils 'zypper_call';
use y2lan_utils;

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call "in yast2-network";    # make sure yast2 lan module installed

    # those two are for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

    my $opened = open_yast2_lan_first_time;
    wait_still_screen;
    if ($opened eq "Controlled by network manager") {
        return;
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

    close_yast2_lan;

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
