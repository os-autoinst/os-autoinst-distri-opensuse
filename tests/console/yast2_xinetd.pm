# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: xinetd yast2-inetd
# Summary: yast2_xinetd checks start and stop of verious server components and add or delete server components
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "y2_module_consoletest";

use testapi;
use utils;
use Utils::Logging 'problem_detection';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    # install xinetd at first
    zypper_call("in xinetd yast2-inetd", timeout => 180);

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'xinetd');

    # check xinetd network configuration got started
    assert_screen([qw(yast2_xinetd_startup yast2_xinetd_core-dumped)], 90);
    if (match_has_tag('yast2_xinetd_core-dumped')) {
        # softfail when yast2 crashed and throws core dumped message
        # we need logs even after yast2 got crashed
        record_soft_failure "bsc#1049433";
        problem_detection();
        return;

    }

    # enable xinetd
    send_key 'alt-l';
    wait_still_screen 1;

    # toggle status on at first and then off
    send_key 'alt-s';
    wait_still_screen 1;
    send_key 'alt-d';
    wait_still_screen 1;

    # deactivate all services
    assert_screen 'yast2_xinetd_all_deactivated';
    send_key 'alt-s';
    wait_still_screen 1;

    # activate all services
    send_key 'alt-a';
    wait_still_screen 1;

    # try to delete an item which is not installed at all
    send_key 'alt-d';
    assert_screen 'yast2_xinetd_cannot_delete';
    send_key 'alt-o';
    wait_still_screen 1;

    # delete ftp configuration from the list
    send_key_until_needlematch 'yast2_xinetd_ftp_deleted', 'down';
    send_key 'alt-d';
    wait_still_screen 1;
    assert_screen 'yast2_xinetd_cannot_delete_again';
    wait_screen_change { send_key 'alt-o'; };

    # add a service
    send_key 'alt-a';
    wait_still_screen 1;
    type_string 'super_ping';
    wait_still_screen 1;
    send_key 'alt-e';
    wait_still_screen 1;
    type_string 'localhost';
    wait_still_screen 1;
    send_key 'alt-m';
    wait_still_screen 1;
    type_string 'fake, useless, nobody should use it, use ping instead of it ;)';
    wait_still_screen 1;
    send_key 'alt-a';
    wait_still_screen 1;

    # close xinetd with finish
    wait_screen_change { send_key 'alt-f'; };

    # wait till xinetd got closed
    wait_serial("$module_name-0", 180) || die "'yast2 xinetd' didn't finish";

    # check xinetd configuration
    systemctl 'show -p ActiveState xinetd.service | grep ActiveState=active';
}
1;

