# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tftp yast2-tftp-server
# Summary: configure and test tftp server
# FTP Server Wizard
# Step 1: Install package and dependencies;
# Step 2: Set TFTP root directory;
# Step 3: Check firewall with needles, open ports if needed;
# Step 4: Check for error logs;
# Step 5: tFTP server is created, new file created inside it;
# Step 6: get the created file from the new tFTP server;
# Step 7: Send finish command exits the app.
# Maintainer: Sergio R Lemke <slemke@suse.com>

use strict;
use warnings;
use base "y2_module_consoletest";

use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);

sub run {
    select_console 'root-console';
    zypper_call("in tftp yast2-tftp-server", timeout => 240);
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'tftp-server');
    wait_still_screen(6);
    assert_screen 'yast2_tftp-server_configuration_main_screen';    #raw main screen
    my $firewall_detail_shortcut = 'alt-i';

    if (is_sle('>15') || is_leap('>15.0') || is_tumbleweed) {
        sleep 10 if is_sle('>15');    #15.1 needs little more time to initialize
        send_key 'alt-t';
        send_key 'up';    #selects 'Start'
        send_key 'ret';    #confirm

        send_key 'alt-a';    #start service after reboot
        send_key 'up';    #selects 'Start on demand'
        send_key 'ret';    #confirm

        send_key 'alt-i';    #enter boot image directory field
        $firewall_detail_shortcut = 'alt-d';
    } else {
        sleep 10 if is_sle('=15');    #15.0 needs little more time to initialize
        assert_screen 'yast2_tftp-server_configuration';    #main screen with service status
        send_key 'alt-e';    # enable tftp
        send_key 'alt-t';    #enter boot image directory field
    }
    wait_still_screen(3);
    assert_screen([qw(yast2_tftp-server_configuration_enabled yast2_tftp-server_configuration_enabled_new)]);

    for (1 .. 20) { send_key 'backspace'; }
    wait_still_screen(3);
    my $tftpboot_newdir = '/srv/tftpboot/new_dir';
    type_string_slow $tftpboot_newdir;
    assert_screen 'yast2_tftp-server_configuration_newdir_typed';

    # open port in firewall, if needed
    assert_screen([qw(yast2_tftp_open_port yast2_tftp_closed_port yast2_tftp_no_network_interfaces)]);

    # we only need to open the port if closed:
    if (match_has_tag('yast2_tftp_closed_port')) {
        send_key 'alt-f';    # open tftp port in firewall
        assert_screen 'yast2_tftp_open_port';
        send_key $firewall_detail_shortcut;    # open firewall details window
        assert_screen 'yast2_tftp_firewall_details';
        send_key 'alt-o';    # close the window
        assert_screen 'yast2_tftp_open_port';    # assert that window is closed
    }
    # bsc#1207390, skip open firewall ports for tumbleweed
    elsif (match_has_tag('yast2_tftp_no_network_interfaces') && is_tumbleweed) {
        assert_screen 'yast2_tftp_no_network_interfaces';
    }

    # view log
    send_key 'alt-v';    # open log window

    # bsc#1008493 is still open, but error pop-up doesn't always appear immediately
    # so wait still screen before assertion
    wait_still_screen 3;
    assert_screen([qw(yast2_tftp_view_log_error yast2_tftp_view_log_show yast2_tftp_view_journal)]);

    if (match_has_tag('yast2_tftp_view_log_error')) {
        # softfail for opensuse when error for view log throws out
        record_soft_failure "bsc#1008493";
        wait_screen_change { send_key 'alt-o' };    # confirm the error message
        send_key 'alt-c';    # close that error window
    }
    elsif (match_has_tag('yast2_tftp_view_journal')) {
        # open filter settings pop-up
        send_key 'alt-c';
        assert_screen('yast2_tftp_view_journal_filter');
        # close pop-up & quit Journal Entries view
        wait_screen_change { send_key 'alt-o' };
        send_key 'alt-q';
    }
    else {
        send_key 'alt-c';    # close the window
    }

    # now finish tftp server configuration
    send_key 'alt-o';    # confirm changes

    # and confirm for creating new directory
    assert_screen 'yast2_tftp_create_new_directory';
    send_key 'alt-y';    # approve creation of new directory

    # wait for yast2 tftp configuration completion
    wait_serial("$module_name-0", 180) || die "'yast2 tftp-server' failed";

    # create a test file for tftp server
    my $server_string = 'This is a QA tftp server';
    assert_script_run "echo $server_string > $tftpboot_newdir/test";

    # check tftp server
    assert_script_run 'tftp localhost -c get test';
    assert_script_run "echo $server_string | cmp - test";
}

1;
