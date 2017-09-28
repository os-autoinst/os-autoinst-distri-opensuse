# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_ntpclient test
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;
use utils qw(type_string_slow zypper_call);

sub run {
    select_console 'root-console';
    # Test often fails due to info kernel messages disrupting screen
    # Decrease logging level to warning to avoid this
    assert_script_run "dmesg -n 4";
    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # install squid package at first
    zypper_call("in yast2-ntp-client", timeout => 180);

    # start NTP configuration
    script_run("yast2 ntp-client; echo yast2-ntp-client-status-\$? > /dev/$serialdev", 0);

    # check Advanced NTP Configuration is opened
    assert_screen([qw(yast2_ntp-client_configuration yast2_ntp-needs_install)], 90);
    if (match_has_tag 'yast2_ntp-needs_install') {
        send_key 'alt-i';
        assert_screen 'yast2_ntp-client_configuration';
    }
    if (match_has_tag 'bsc#1058475') {
        record_soft_failure 'bsc#1058475';
        send_key 'alt-o';
        wait_still_screen(2);
        send_key 'alt-o';
        wait_still_screen(2);
        send_key 'f9';
        wait_still_screen(2);
        return;
    }

    # use Synchronize without daemon
    send_key 'alt-y';
    assert_screen 'yast2_ntp-client_synchronize_without_daemon';

    # check Runtime Configuration Policy
    wait_screen_change { send_key 'alt-r'; };
    send_key 'up';
    assert_screen 'yast2_ntp-client_runtime_config_up';
    send_key 'down';
    wait_screen_change { send_key 'ret'; };

    # change Interval of Synchronization
    send_key 'alt-n';
    type_string_slow "1\n";

    # check new interval of synchronization time
    assert_screen 'yast2_ntp-client_new_interval';

    # add a new synchronization
    send_key 'alt-a';

    # check page new sychronization
    assert_screen 'yast2_ntp-client_new_synchronization';
    # select type of synchronization: server, then go next
    send_key_until_needlematch 'yast2_ntp-client_sync_server', 'alt-s';
    send_key 'alt-n';

    # check NTP Server is displayed for changes
    assert_screen 'yast2_ntp-client_ntp_server';

    # select public ntp server
    send_key 'alt-s';
    assert_screen 'yast2_ntp-client_ntp_server_public';
    wait_screen_change { send_key 'down'; };
    send_key 'ret';

    # check public ntp server is showing up and select UK
    assert_screen 'yast2_ntp-client_public_ntp_server_opened';
    send_key 'alt-u';
    assert_screen 'yast2_ntp-client_public_ntp_country';
    send_key_until_needlematch 'yast2_ntp-client_country_uk', 'up';
    wait_screen_change { send_key 'ret'; };
    send_key 'alt-s';
    assert_screen 'yast2_ntp-client_public_ntp_server_uk';
    send_key 'ret';

    # run test
    send_key 'alt-t';
    assert_screen 'yast2_ntp-client_public_ntp_test';

    # close it with OK
    send_key_until_needlematch "yast2_ntp-client_public_ntp_server_added", "alt-o", 3, 5;

    # now check display log and save log
    send_key 'alt-l';

    # check log got displayed and go to Advanced
    assert_screen 'yast2_ntp-client_display_log';
    send_key 'alt-v';
    assert_screen 'yast2_ntp-client_display_log_save_log';
    send_key 'ret';

    # give a new file name
    assert_screen 'yast2_ntp-client_save_log_as';
    send_key 'alt-f';
    type_string 'ntpclient.log';
    assert_screen 'yast2_ntp-client_new_file_name';
    send_key 'alt-o';
    assert_screen 'yast2_ntp-client_display_log';
    wait_still_screen 1;
    send_key 'alt-c';
    # Assert that we are back to configuration page
    assert_screen 'yast2_ntp-client_configuration';
    wait_still_screen 1;
    # finish ntp client configuration after help page got opened
    send_key 'alt-h';
    assert_screen 'yast2_ntp-client_help', 60;
    wait_screen_change { send_key 'alt-o'; };
    # Press ok to finish configuration
    wait_screen_change { send_key 'alt-o'; };

    wait_serial('yast2-ntp-client-status-0', 180);

    # add NTPD_FORCE_SYNC_ON_STARTUP=yes into /etc/ntp.conf, ntpd should start up at once
    script_run("echo NTPD_FORCE_SYNC_ON_STARTUP=yes >> /etc/ntp.conf");
    script_run("systemctl restart ntpd.service");

    # check NTP synchronization
    assert_script_run("systemctl show -p ActiveState ntpd.service | grep ActiveState=active");
}
1;

# vim: set sw=4 et:
