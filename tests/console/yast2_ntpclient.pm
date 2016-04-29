# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;



sub run() {

    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # install squid package at first
    assert_script_run("/usr/bin/zypper -n -q in yast2-ntp-client");

    # start NTP configuration
    script_run("/sbin/yast2 ntp-client; echo yast2-ntp-client-status-\$? > /dev/$serialdev", 0);

    # check Advanced NTP Configuration is opened
    assert_screen 'yast2_ntp-client_configuration';

    # use Synchronize without daemon
    send_key 'alt-y';
    assert_screen 'yast2_ntp-client_synchronize_without_daemon';

    # check Runtime Configuration Policy
    send_key 'alt-r';
    send_key 'up';
    assert_screen 'yast2_ntp-client_runtime_config_up';
    send_key 'down';
    send_key 'ret';

    # change Interval of Synchronization
    send_key 'alt-n';
    for (1 .. 5) { send_key 'down'; }

    # check new interval of synchronization time
    assert_screen 'yast2_ntp-client_new_interval';

    # add a new synchronization
    send_key 'alt-a';

    # check page new sychronization
    assert_screen 'yast2_ntp-client_new_synchronization';
    # select type of synchronization: server, then go next
    send_key 'alt-p';
    send_key 'alt-s';
    send_key 'alt-n';

    # check NTP Server is displayed for changes
    assert_screen 'yast2_ntp-client_ntp_server';

    # select public ntp server
    send_key 'alt-s';
    assert_screen 'yast2_ntp-client_ntp_server_public';
    send_key 'down';
    send_key 'ret';

    # check public ntp server is showing up and select UK
    assert_screen 'yast2_ntp-client_public_ntp_server_opened';
    send_key 'alt-u';
    assert_screen 'yast2_ntp-client_public_ntp_country';
    # save screenshots at first
    #	for (1..80) {send_key 'up'; save_screenshot;}
    send_key_until_needlematch 'yast2_ntp-client_country_uk', 'up';
    assert_screen 'yast2_ntp-client_country_uk';
    send_key 'ret';
    send_key 'alt-s';
    assert_screen 'yast2_ntp-client_public_ntp_server_uk';
    send_key 'ret';

    # run test
    send_key 'alt-t';
    assert_screen 'yast2_ntp-client_public_ntp_test';
    send_key 'alt-o';

    # close it with OK
    send_key 'alt-o';
    wait_still_screen;
    send_key 'alt-o';


    # now check display log and save log
    send_key 'alt-l';

    # check log got displayed and go to Advanced
    assert_screen 'yast2_ntp-client_display_log';
    send_key 'alt-v';
    assert_screen 'yast2_ntp-client_display_log_save_log';
    send_key 'ret';

    # give a new file name
    send_key 'alt-f';
    assert_screen 'yast2_ntp-client_save_log_as';
    for (1 .. 20) { send_key 'backspace'; }
    type_string 'ntpclient.log';
    assert_screen 'yast2_ntp-client_new_file_name';
    send_key 'alt-o';
    send_key 'alt-c';

    # finish ntp client configuration after help page got opened
    send_key 'alt-h';

    # check Help is displayed
    assert_screen 'yast2_ntp-client_help';
    send_key 'tab';
    send_key 'down';
    send_key 'alt-o';
    send_key 'alt-o';

    wait_serial('yast2-ntp-client-status-0', 60);

    # check NTP synchronization
    assert_script_run('/usr/bin/timedatectl | grep "NTP synchronized: yes"');

}
1;

# vim: set sw=4 et:
