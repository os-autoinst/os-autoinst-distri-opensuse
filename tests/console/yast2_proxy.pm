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

    # install yast2-squid, yast2-proxy, squid package at first
    assert_script_run("/usr/bin/zypper -n -q in squid yast2-squid yast2-proxy");

    # start yast2 squid configuration
    script_run("/sbin/yast2 squid; echo yast2-squid-status-\$? > /dev/$serialdev", 0);

    # check that squid configuration page shows up
    assert_screen 'yast2_proxy_squid';

    # enable service start
    send_key 'alt-b';

    # if firewall is enabled, then send_key alt-p, else move to page http ports
    if (check_screen 'yast2_proxy_firewall_enabled') { send_key 'alt-p'; }
    send_key 'alt-d';

    # check network interfaces with open port in firewall
    assert_screen 'yast2_proxy_network_interfaces';
    send_key 'alt-n';
    send_key 'alt-a';
    send_key 'alt-o';

    # move to http ports
    send_key_until_needlematch 'yast2_proxy_start-up', 'tab';
    send_key 'down';
    send_key 'ret';

    # edit details of http ports setting
    send_key 'alt-i';

    # check dialog "edit current http port"
    assert_screen 'yast2_proxy_http_ports_current';
    send_key 'alt-h';
    type_string 'localhost';
    send_key 'alt-p';
    for (1 .. 6) { send_key 'backspace'; }
    type_string '80';
    send_key 'alt-t';
    assert_screen 'yast2_proxy_http_port_transparent';
    send_key 'alt-o';
    assert_screen 'yast2_proxy_http_ports_edit';

    #	move to page refresh patterns
    send_key_until_needlematch 'yast2_proxy_http_ports_selected', 'tab';
    send_key 'down';
    send_key 'ret';

    # check refresh patterns page is opend
    assert_screen 'yast2_proxy_refresh_patterns';
    # change the order here
    send_key 'alt-w';
    assert_screen 'yast2_proxy_refresh_patterns_oder';

    # move to page cache setting
    send_key_until_needlematch 'yast2_proxy_http_refresh_patterns_selected', 'shift-tab';
    send_key 'down';
    send_key 'ret';

    # change some value in cache settings
    send_key 'alt-a';
    for (1 .. 3) { send_key 'up'; }
    send_key 'alt-x';
    for (1 .. 10) { send_key 'down'; }
    send_key 'alt-i';
    for (1 .. 3) { send_key 'up'; }
    send_key 'alt-l';
    for (1 .. 3) { send_key 'down'; }
    send_key 'alt-s';
    for (1 .. 3) { send_key 'down'; }
    send_key 'alt-e';
    for (1 .. 3) { send_key 'down'; }
    send_key 'ret';
    send_key 'alt-m';
    for (1 .. 3) { send_key 'down'; }
    send_key 'ret';

    # check new value in cache settings
    assert_screen 'yast2_proxy_cache_settings_new';

    # move to page cache directory
    send_key_until_needlematch 'yast2_proxy_http_cache_setting_selected', 'shift-tab';
    send_key 'down';
    send_key 'ret';

    # check the page cache directory is opened for a new directory name and other changes
    assert_screen 'yast_proxy_cache_directory_name';
    send_key 'alt-d';
    for (1 .. 20) { send_key 'backspace'; }
    type_string "/var/cache/squid1";
    send_key 'alt-s';
    for (1 .. 20) { send_key 'up'; }
    send_key 'alt-e';
    for (1 .. 4) { send_key 'up'; }
    send_key 'alt-v';
    for (1 .. 10) { send_key 'down'; }

    # check the changes made correctly
    assert_screen 'yast_proxy_cache_directory_new';

    # move to page Access Control to edit ACL Groups
    send_key_until_needlematch 'yast2_proxy_http_cache_directory_selected', 'shift-tab';
    send_key 'down';
    #	confirm to create new directory
    send_key 'ret';
    send_key 'alt-y';
    send_key 'tab';
    send_key 'down';
    send_key 'down';
    send_key 'alt-i';
    send_key 'alt-e';
    send_key 'backspace';
    type_string '8';
    send_key 'alt-o';

    # move to Access Control and change something
    send_key 'tab';
    send_key 'tab';
    send_key 'alt-w';
    send_key 'alt-w';

    # check changes in ACL Groups and Access Control
    assert_screen 'yast2_proxy_access_control_new';

    # move to Logging and Timeouts
    send_key_until_needlematch 'yast2_proxy_http_access_control_selected', 'shift-tab';
    send_key 'down';
    send_key 'ret';
    # check logging and timeouts setting is opened to edit
    assert_screen 'yast2_proxy_logging_timeouts_setting';
    send_key 'alt-a';
    send_key 'alt-w';

    # check acces log directory can be browsed and defined
    assert_screen 'yast2_proxy_access_log_directory';
    send_key 'alt-c';
    send_key 'alt-g';
    for (1 .. 40) { send_key 'backspace'; }
    type_string "/var/log/squid/proxy_cache.log";
    send_key 'alt-s';
    for (1 .. 40) { send_key 'backspace'; }
    type_string "/var/log/squid/proxy_store.log";
    send_key 'alt-e';

    # move to timeouts now
    send_key 'alt-t';
    send_key 'up';
    send_key 'alt-l';
    send_key 'up';

    # check above changes for logging and timeouts
    assert_screen 'yast2_proxy_logging_timeouts_new';
    #	move to miscellanous now for change language into de-de and admin email
    send_key_until_needlematch 'yast2_proxy_logging_timeouts_selected', 'shift-tab';
    send_key 'down';
    send_key 'ret';
    send_key 'alt-l';
    for (1 .. 5) { send_key 'up'; }
    send_key 'ret';
    send_key 'alt-a';
    for (1 .. 10) { send_key 'backspace'; }
    type_string 'webmaster@localhost';

    # check language and email now
    assert_screen 'yast2_proxy_miscellanous';

    # move to Start-Up and start proxy server now
    #	for (1..35) {send_key 'tab'; save_screenshot;}
    send_key_until_needlematch 'yast2_proxy_miscellanous_selected', 'shift-tab';
    for (1 .. 7) { send_key 'up'; }
    send_key 'ret';

    # now save settings and start squid server
    send_key 'alt-s';
    #	check again before to close configuration
    assert_screen 'yast2_proxy_before_close';
    # finish configuration with OK
    send_key 'alt-o';

    # yast might take a while on sle12 due to suseconfig
    wait_serial("yast2-squid-status-0", 60) || die "'yast2 squid' didn't finish";

    # check squid proxy server status
    assert_script_run "systemctl show -p ActiveState squid.service|grep ActiveState=active";
    assert_script_run "systemctl show -p SubState squid.service|grep SubState=running";

}
1;

# vim: set sw=4 et:
