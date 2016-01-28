# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "console_yasttest";
use testapi;
use utils;

# test yast2 lan functionality
# https://bugzilla.novell.com/show_bug.cgi?id=600576

sub run() {
    my $self = shift;

    select_console 'user-console';
    assert_script_sudo "zypper -n in yast2-network";    # make sure yast2 lan module installed

    # those two are for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

    script_sudo("/sbin/yast2 lan", 0);

    assert_screen [qw/Networkmanager_controlled yast2_lan install-susefirewall2/], 60;
    if (match_has_tag('Networkmanager_controlled')) {
        send_key "ret";                                 # confirm networkmanager popup
        assert_screen "Networkmanager_controlled-approved";
        send_key "alt-c";
        if (check_screen('yast2-lan-really', 3)) {
            # SLED11...
            send_key 'alt-y';
        }
        assert_screen 'yast2-lan-exited', 30;
        return;                                         # don't change any settings
    }
    if (match_has_tag('install-susefirewall2')) {
        send_key "alt-i";                               # install SuSEfirewall2
        assert_screen "yast2_lan", 30;                  # check yast2_lan again after SuSEfirewall2 installed
    }

    my $hostname = "susetest";
    my $domain   = "zq1.de";

    send_key "alt-s";                                   # open hostname tab
    assert_screen "yast2_lan-hostname-tab";
    send_key "tab";
    for (1 .. 15) { send_key "backspace" }
    type_string $hostname;
    send_key "tab";
    for (1 .. 15) { send_key "backspace" }
    type_string $domain;
    assert_screen 'test-yast2_lan-1';

    send_key "alt-o";                                   # OK=>Save&Exit
    assert_screen 'yast2-lan-exited', 90;

    clear_console;
    script_run('echo $?');
    script_run('hostname');
    assert_screen 'test-yast2_lan-2';

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;

# vim: set sw=4 et:
