# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-ntp-client ntpd chronyd
# Summary: yast2_ntpclient test
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "y2_module_consoletest";

use testapi;
use utils qw(enter_cmd_slow zypper_call systemctl);
use version_utils qw(is_sle is_leap);

sub run {
    select_console 'root-console';

    # Most distribution still use ntpd
    my $ntp_service = 'ntpd';

    # ntp configuration is different in SLE15/Leap15
    # for now, Tumbleweed doesn't use Chrony
    # use sle_or_leap_15 variable to avoid executing is_* and *_version_at_least multiple time
    my $is_chronyd = (!is_sle('<15') && !is_leap('<15.0')) ? 1 : 0;
    $ntp_service = 'chronyd' if ($is_chronyd);

    # if support-server is used
    my $ntp_server = check_var('USE_SUPPORT_SERVER', 1) ? 'ns' : '0.opensuse.pool.ntp.org';

    # check network at first
    assert_script_run('if ! systemctl -q is-active network; then systemctl -q start network; fi');

    # install squid package at first
    zypper_call("in yast2-ntp-client", timeout => 180);

    # start NTP configuration
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'ntp-client');

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
    send_key $cmd{sync_without_daemon};
    assert_screen 'yast2_ntp-client_synchronize_without_daemon';

    # check Runtime Configuration Policy in SLE < 15
    if (!$is_chronyd) {
        wait_screen_change { send_key 'alt-r'; };
        send_key 'up';
        assert_screen 'yast2_ntp-client_runtime_config_up';
        send_key 'down';
        wait_screen_change { send_key 'ret'; };
    }

    # change Interval of Synchronization
    send_key $cmd{sync_interval};
    enter_cmd_slow "1";

    # check new interval of synchronization time
    assert_screen 'yast2_ntp-client_new_interval';

    # add a new synchronization
    send_key 'alt-a';

    # check page new sychronization
    assert_screen 'yast2_ntp-client_new_synchronization';

    # select type of synchronization: server, then go next
    if ($is_chronyd) {
        type_string "$ntp_server";
    }
    else {
        # select type of synchronization: server, then go next
        send_key_until_needlematch 'yast2_ntp-client_sync_server', 'alt-s';
        send_key 'alt-n';

        # check ntp server is displayed for changes
        assert_screen 'yast2_ntp-client_ntp_server';

        # if support-server is used we need to select it
        if (check_var('USE_SUPPORT_SERVER', 1)) {
            type_string "$ntp_server";
        }
        else {
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
        }
    }

    # run test
    send_key 'alt-t';
    assert_screen 'yast2_ntp-client_public_ntp_test';

    # close it with OK
    my $ntp_client_needle = check_var('USE_SUPPORT_SERVER', 1) ? 'support_server' : 'public';
    send_key_until_needlematch "yast2_ntp-client_${ntp_client_needle}_ntp_server_added", "alt-o", 4, 5;

    if (!$is_chronyd) {
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

        # assert that we are back to configuration page
        send_key_until_needlematch('yast2_ntp-client_configuration', 'alt-c');
        wait_still_screen 1;
    }

    # at the end, use Now and on Boot daemon configuration
    send_key 'alt-b';
    assert_screen 'yast2_ntp-client_synchronize_on_boot';

    # finish ntp client configuration after help page got opened
    send_key 'alt-h';
    assert_screen 'yast2_ntp-client_help', 60;
    wait_screen_change { send_key 'alt-o'; };

    # press ok to finish configuration
    wait_screen_change { send_key 'alt-o'; };
    wait_serial("$module_name-0", 180);

    # modify /etc/sysconfig/ntp (and not /etc/ntp.conf!!) to add NTPD_FORCE_SYNC_ON_STARTUP=yes
    script_run('sed -i \'s/^\\(NTPD_FORCE_SYNC_ON_STARTUP=\\).*$/\\1yes/\' /etc/sysconfig/ntp') if (!$is_chronyd);

    # Verify that ntp server is added to the config file
    assert_script_run("grep 'pool $ntp_server' /etc/chrony.d/pool.conf") if $is_chronyd;

    # restart ntp daemon
    systemctl "restart $ntp_service.service";

    # check ntp synchronization service state
    systemctl "show -p ActiveState $ntp_service.service | grep ActiveState=active";
}
1;
