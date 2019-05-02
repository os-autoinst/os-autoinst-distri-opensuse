# SUSE's openQA tests
#
# Copyright (c) 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: configure and test tftp server
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "console_yasttest";
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use yast2_widget_utils 'change_service_configuration';

sub run {
    select_console 'root-console';
    zypper_call("in tftp yast2-tftp-server", timeout => 240);
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'tftp-server');
    # make sure the module is loaded and any potential popups are there to be
    # asserted later
    wait_still_screen(3);
    my $boot_image_dir_shortcut  = 'alt-i';
    my $firewall_detail_shortcut = 'alt-d';
    if (is_sle('<15') || is_leap('<15.1')) {
        assert_screen 'yast2_tftp-server_configuration';
        send_key 'alt-e';    # enable tftp
        assert_screen 'yast2_tftp-server_configuration_enabled';
        $boot_image_dir_shortcut  = 'alt-t';
        $firewall_detail_shortcut = 'alt-i';
    }
    else {
        change_service_configuration(
            after_writing => {start           => 'alt-t'},
            after_reboot  => {start_on_demand => 'alt-a'}
        );
    }
    # provide a new TFTP root directory path
    # workaround to resolve problem with first key press is lost, improve stability here by retrying
    send_key_until_needlematch 'yast2_tftp-server_configuration_chdir', $boot_image_dir_shortcut, 2, 3;
    for (1 .. 20) { send_key 'backspace'; }
    my $tftpboot_newdir = '/srv/tftpboot/new_dir';
    type_string $tftpboot_newdir;
    assert_screen 'yast2_tftp-server_configuration_newdir_typed';

    # open port in firewall, if needed
    assert_screen([qw(yast2_tftp_open_port yast2_tftp_closed_port)]);
    if (match_has_tag('yast2_tftp_open_port')) {
        send_key 'alt-f';    # open tftp port in firewall
        assert_screen 'yast2_tftp_port_opened';
        send_key $firewall_detail_shortcut;    # open firewall details window
        assert_screen 'yast2_tftp_firewall_details';
        send_key 'alt-o';                      # close the window
        assert_screen 'yast2_tftp_closed_port';
    }

    # view log
    send_key 'alt-v';                          # open log window

    # bsc#1008493 is still open, but error pop-up doesn't always appear immediately
    # so wait still screen before assertion
    wait_still_screen 3;
    assert_screen([qw(yast2_tftp_view_log_error yast2_tftp_view_log_show yast2_tftp_view_journal)]);
    if (match_has_tag('yast2_tftp_view_log_error')) {
        # softfail for opensuse when error for view log throws out
        record_soft_failure "bsc#1008493";
        wait_screen_change { send_key 'alt-o' };    # confirm the error message
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
        send_key 'alt-c';                           # close the window
    }

    assert_screen 'yast2_tftp_closed_port';
    # now finish tftp server configuration
    send_key 'alt-o';                               # confirm changes

    # and confirm for creating new directory
    assert_screen 'yast2_tftp_create_new_directory';
    send_key 'alt-y';                               # approve creation of new directory

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
