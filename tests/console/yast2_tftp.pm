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
use base "consoletest";
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    zypper_call("in tftp yast2-tftp-server");

    script_run("yast2 tftp-server; echo yast2-tftp-server-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2_tftp-server_configuration';

    send_key 'alt-e';    # enable tftp
    assert_screen 'yast2_tftp-server_configuration_enabled';

    # provide a new TFTP root directory path
    send_key 'alt-t';    # select input field
    assert_screen 'yast2_tftp-server_configuration_chdir';
    for (1 .. 20) { send_key 'backspace'; }
    my $tftpboot_newdir = '/srv/tftpboot/new_dir';
    type_string $tftpboot_newdir;
    assert_screen 'yast2_tftp-server_configuration_newdir_typed';

    # open port in firewall, if needed
    assert_screen([qw(yast2_tftp_open_port yast2_tftp_closed_port)]);
    if (match_has_tag('yast2_tftp_open_port')) {
        send_key 'alt-f';    # open tftp port in firewall
        assert_screen 'yast2_tftp_port_opened';
        send_key 'alt-i';    # open firewall details window
        assert_screen 'yast2_tftp_firewall_details';
        send_key 'alt-o';    # close the window
        assert_screen 'yast2_tftp_closed_port';
    }

    # view log
    send_key 'alt-v';        # open log window
    assert_screen([qw(yast2_tftp_view_log_error yast2_tftp_view_log_show)]);
    if (match_has_tag('yast2_tftp_view_log_error')) {
        # softfail for opensuse when error for view log throws out
        record_soft_failure "bsc#1008493";
        send_key 'alt-o';    # confirm the error message
    }
    send_key 'alt-c';        # close the window
    assert_screen 'yast2_tftp_closed_port';

    # now finish tftp server configuration
    send_key 'alt-o';        # confirm changes

    # and confirm for creating new directory
    assert_screen 'yast2_tftp_create_new_directory';
    send_key 'alt-y';        # approve creation of new directory

    # wait 60 seconds for yast2 tftp configuration got completed.
    wait_serial("yast2-tftp-server-status-0") || die "'yast2 tftp-server' failed";
    assert_screen 'yast2_console-finished';

    # create a test file for tftp server
    my $server_string = 'This is a QA tftp server';
    assert_script_run "echo $server_string > $tftpboot_newdir/test";

    # check tftp server
    assert_script_run 'tftp localhost -c get test';
    assert_script_run "echo $server_string | cmp - test";
}

1;

# vim: set sw=4 et:
