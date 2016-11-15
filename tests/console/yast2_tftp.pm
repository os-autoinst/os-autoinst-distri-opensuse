# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
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



sub run() {
    select_console 'root-console';

    # install tftp and yast2-tftp-server
    assert_script_run("/usr/bin/zypper -n -q in tftp yast2-tftp-server");

    # start tftp-server configuration
    script_run("yast2 tftp-server; echo yast2-tftp-server-status-\$? > /dev/$serialdev", 0);

    # check yast2 tftp-server configuration is opened
    assert_screen 'yast2_tftp-server_configuration';

    # select enable tftp
    send_key 'alt-e';

    # give a new file path for boot image directory
    send_key 'alt-t';
    for (1 .. 20) {
        send_key 'backspace';
    }

    type_string '/srv/tftpboot/new_dir';

    # open port in firewall, if firewall is disabled, then continue with next test view log

    assert_screen([qw(yast2_tftp_open_port yast2_tftp_closed_port)]);
    if (match_has_tag('yast2_tftp_open_port')) {
        send_key 'alt-f';
        send_key 'alt-i';
        assert_screen 'yast2_tftp_firewall_details';
        send_key 'alt-o';
        assert_screen 'yast2_tftp_closed_port';
    }

    # view log
    send_key 'alt-v';
    assert_screen([qw(yast2_tftp_view_log_error yast2_tftp_view_log_show)]);
    record_soft_failure "bsc#1008493";
    if (match_has_tag('yast2_tftp_view_log_error')) {
        send_key 'alt-o';
        assert_screen 'yast2_tftp_view_log_show';
        send_key 'alt-c';
        wait_still_screen 1;
    }

    # check help text
    send_key 'alt-h';
    assert_screen 'yast2_tftp_show_help';
    send_key 'alt-o';

    # now finish tftp server configuration
    send_key 'alt-o';
    sleep 2;

    # and confirm for creating new directory
    assert_screen 'yast2_tftp_create_new_directory';
    send_key 'alt-y';

    # wait 60 seconds for yast2 tftp configuration got completed.
    wait_serial("yast2-tftp-server-status-0", 60) || die "'yast2 tftp-server' didn't finish";

    # create a test file for tftp server
    assert_script_run('echo "QA tftp server, welcome" > /srv/tftpboot/new_dir/test');

    # check tftp server
    assert_script_run('tftp localhost -c get test');


}
1;

# vim: set sw=4 et:
