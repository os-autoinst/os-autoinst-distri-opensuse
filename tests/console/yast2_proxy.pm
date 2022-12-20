# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: squid yast2-squid yast2-proxy
# Summary: Test that squid proxy can be started after setup with YaST
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "y2_module_consoletest";

use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);
use yast2_widget_utils 'change_service_configuration';

my %sub_menu_needles = (
    start_up => 'yast2_proxy_start-up',
    http_ports => 'yast2_proxy_http_ports_selected',
    patterns => 'yast2_proxy_http_refresh_patterns_selected',
    cache_setting => 'yast2_proxy_http_cache_setting_selected',
    cache_dir => 'yast2_proxy_http_cache_directory_selected',
    access_ctrl => 'yast2_proxy_http_access_control_selected',
    log_timeouts => 'yast2_proxy_logging_timeouts_selected',
    miscellaneous => 'yast2_proxy_miscellaneous_selected'
);

sub select_sub_menu {
    my ($initial_screen, $wanted_screen) = @_;
    send_key_until_needlematch $sub_menu_needles{$initial_screen}, 'tab';
    wait_still_screen 1;
    send_key 'down';
    assert_screen $sub_menu_needles{$wanted_screen};
    wait_still_screen 1;
    wait_screen_change { send_key 'ret'; };
    wait_still_screen 1;
}

sub empty_field {
    my ($shortkey, $empty_field_needle, $symbols_to_remove) = @_;
    $symbols_to_remove //= 20;

    for my $i (0 .. $symbols_to_remove) {
        send_key $shortkey;
        send_key 'backspace';
        return if check_screen $empty_field_needle, 0;
    }
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    upload_logs("/etc/squid/squid.conf");
    upload_logs("/var/log/squid/access.log");
    upload_logs("/var/log/squid/proxy_cache.log");
    upload_logs("/var/log/squid/proxy_store.log");
}

sub run {
    select_console 'root-console';

    # install yast2-squid, yast2-proxy, squid package at first
    zypper_call("in squid yast2-squid yast2-proxy", timeout => 180);

    # set up visible_hostname or squid spends 30s trying to determine public hostname
    script_run 'echo "visible_hostname $HOSTNAME" >> /etc/squid/squid.conf';

    # start yast2 squid configuration
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'squid');

    # check that squid configuration page shows up
    assert_screen([qw(yast2_proxy_squid yast2_still_susefirewall2)], 60);
    my $is_still_susefirewall2;
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure 'bsc#1064405';
        send_key 'alt-c';
        $is_still_susefirewall2 = 1;
    }

    # enable service start
    if (is_sle('<15') || is_leap('<15.1')) {
        send_key_until_needlematch 'yast2_proxy_service_start', 'alt-b';    #Start service when booting
    }
    else {
        change_service_configuration(
            after_writing => {start => 'alt-f'},
            after_reboot => {start_on_boot => 'alt-a'}
        );
    }

    # if firewall is enabled, then send_key alt-p, else move to page http ports
    unless ($is_still_susefirewall2) {
        if (check_screen 'yast2_proxy_firewall_enabled', 10) {
            send_key 'alt-p';
            assert_screen([qw(yast2_proxy-port_opened yast2_proxy_squid_cannot-open-interface)]);
            if (match_has_tag 'yast2_proxy_squid_cannot-open-interface') {
                record_soft_failure 'bsc#1069458';
                send_key 'alt-y';
                assert_screen 'yast2_proxy-port_opened';
            }
        }
    }

    # check network interfaces with open port in firewall
    # repeat action as sometimes keys are not triggering action on leap if workers are slow
    if (is_sle('<15') || is_leap('<15.0')) {
        send_key_until_needlematch 'yast2_proxy_network_interfaces', 'alt-d', 3, 5;
        wait_still_screen 1;
        send_key 'alt-n';
        wait_still_screen 1;
        send_key 'alt-a';
        wait_screen_change { send_key 'alt-o' };
    }
    # move to http ports
    select_sub_menu 'start_up', 'http_ports';

    # add a forwarding port
    send_key 'alt-a';

    assert_screen 'yast2_proxy_http_ports_add';
    send_key 'alt-h';
    type_string '0.0.0.0';
    send_key 'alt-p';
    type_string '234';
    send_key 'alt-o';
    assert_screen 'yast2_proxy_http_ports_after_add';

    # edit details of http ports setting
    send_key 'alt-i';

    # check dialog "edit current http port"
    assert_screen 'yast2_proxy_http_ports_current';
    # On leap it happens that field losses it's focus and backspace doesn't remove symbols
    empty_field 'alt-p', 'yast2_proxy_http_port_empty', 10;
    type_string '80';
    send_key 'alt-t';
    assert_screen 'yast2_proxy_http_port_transparent';
    send_key 'alt-o';
    assert_screen 'yast2_proxy_http_ports_edit';

    #	move to page refresh patterns
    select_sub_menu 'http_ports', 'patterns';

    # check refresh patterns page is opend
    assert_screen 'yast2_proxy_refresh_patterns';
    # change the order here
    send_key 'alt-w';
    assert_screen 'yast2_proxy_refresh_patterns_oder';

    # move to page cache setting
    select_sub_menu 'patterns', 'cache_setting';

    # change some value in cache settings
    send_key 'alt-a';
    enter_cmd_slow "11";
    send_key 'alt-x';
    enter_cmd_slow "4086";
    send_key 'alt-i';
    enter_cmd_slow "3";
    send_key 'alt-l';
    enter_cmd_slow "87";
    send_key 'alt-s';
    enter_cmd_slow "92";
    wait_screen_change { send_key 'alt-e'; };
    send_key 'end';
    wait_screen_change { send_key 'ret'; };
    wait_screen_change { send_key 'alt-m'; };
    send_key 'end';
    wait_screen_change { send_key 'ret'; };

    # check new value in cache settings
    assert_screen 'yast2_proxy_cache_settings_new';

    # move to page cache directory
    select_sub_menu 'cache_setting', 'cache_dir';

    # check the page cache directory is opened for a new directory name and other changes
    assert_screen 'yast_proxy_cache_directory_name';
    empty_field 'alt-d', 'yast_proxy_cache_dir_empty', 25;
    type_string_slow "/var/cache/squid1";
    send_key 'alt-s';
    enter_cmd_slow "120";
    send_key 'alt-e';
    enter_cmd_slow "20";
    send_key 'alt-v';
    enter_cmd_slow "246";

    # check the changes made correctly
    assert_screen 'yast_proxy_cache_directory_new';

    # move to page Access Control to edit ACL Groups
    select_sub_menu 'cache_dir', 'access_ctrl';
    assert_screen 'yast2_proxy_http_new_cache_dir';
    send_key 'alt-y';    # confirm to create new directory
    assert_screen 'yast2_proxy_http_access_control_selected';
    wait_still_screen 1;
    # change subnet for 192.168.0.0/16 to 192.168.0.0/18
    wait_screen_change { send_key 'tab'; };
    send_key_until_needlematch 'yast2_proxy_acl_group_localnet_selected', 'down';
    wait_still_screen 1;
    send_key 'alt-i';
    assert_screen 'yast2_proxy_acl_group_edit';
    send_key 'alt-e';
    send_key 'backspace';
    type_string '8';
    wait_screen_change { send_key 'alt-o'; };

    # Verify the subnet is changed to to 192.168.0.0/18 and shown in list
    # (Scroll may be required to see the IP address. So, select "Access Control"
    #  item in the sidebar menu and then press "down" until the IP is found).
    send_key_until_needlematch 'yast2_proxy_http_access_control_selected', 'tab';
    wait_still_screen 1;
    wait_screen_change { send_key 'tab'; };
    send_key_until_needlematch 'yast2_proxy_acl_group_localnet_changed_selected', 'down';

    # move to Access Control and change something
    send_key_until_needlematch 'yast2_proxy_safe_ports_selected', 'tab';
    send_key 'alt-w';
    wait_still_screen 1;
    send_key 'alt-w';

    # check changes in ACL Groups and Access Control
    assert_screen 'yast2_proxy_access_control_new';

    # move to Logging and Timeouts
    select_sub_menu 'access_ctrl', 'log_timeouts';
    # check logging and timeouts setting is opened to edit
    assert_screen 'yast2_proxy_logging_timeouts_setting';
    send_key 'alt-a';
    wait_still_screen 1;
    send_key 'alt-w';

    # check access log directory can be browsed and defined
    assert_screen 'yast2_proxy_access_log_directory';
    wait_still_screen 1;
    send_key 'alt-c';
    wait_still_screen 1;
    send_key 'alt-g';
    empty_field 'alt-e', 'yast2_proxy_cache_log_dir_empty', 35;
    type_string "/var/log/squid/proxy_cache.log";
    empty_field 'alt-s', 'yast2_proxy_store_log_dir_empty', 35;
    type_string "/var/log/squid/proxy_store.log";

    # move to timeouts now
    wait_screen_change { send_key 'alt-t'; };
    wait_screen_change { send_key 'up'; };
    wait_screen_change { send_key 'alt-l'; };
    wait_screen_change { send_key 'up'; };
    # check above changes for logging and timeouts
    assert_screen 'yast2_proxy_logging_timeouts_new';

    #	move to miscellaneous now for change language into de-de and admin email
    select_sub_menu 'log_timeouts', 'miscellaneous';
    wait_screen_change { send_key 'alt-l'; };
    for (1 .. 5) {
        wait_screen_change { send_key 'up'; };
    }
    wait_screen_change { send_key 'ret'; };
    send_key 'alt-a';
    empty_field 'alt-a', 'yast2_proxy_admin_email_empty', 35;
    type_string 'webmaster@localhost';

    # check language and email now
    assert_screen 'yast2_proxy_miscellaneous';

    # move to Start-Up and start proxy server now
    #	for (1..35) {send_key 'tab'; save_screenshot;}
    send_key_until_needlematch 'yast2_proxy_miscellaneous_selected', 'shift-tab';
    send_key_until_needlematch 'yast2_proxy_start-up', 'up';
    wait_still_screen 1;
    send_key 'ret';

    assert_screen 'yast2_proxy_squid';
    wait_still_screen 1;

    if (is_sle('<15') || is_leap('<15.1')) {
        # now save settings and start squid server
        send_key 'alt-s';
        #   check again before to close configuration
        assert_screen 'yast2_proxy_before_close';
        wait_still_screen 1;
    }

    # finish configuration with OK
    wait_screen_change { send_key 'alt-o'; };

    # yast might take a while on sle12 due to suseconfig
    wait_serial("$module_name-0", 360) || die "'yast2 squid' didn't finish";

    # check squid proxy server status
    script_run 'systemctl show -p ActiveState squid.service|grep ActiveState=active';
    systemctl 'show -p SubState squid.service|grep SubState=running';
}

1;
