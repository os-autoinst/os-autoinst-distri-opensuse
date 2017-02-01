# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install packages using yast2.
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "console_yasttest";
use strict;
use testapi;
use utils;

sub run() {
    my $self        = shift;
    my $pkgname     = get_var("PACKAGETOINSTALL_RECOMMENDER", "yast2-nfs-client");
    my $recommended = get_var("PACKAGETOINSTALL_RECOMMENDED", "nfs-client");

    select_console 'root-console';

    zypper_call "-i rm $pkgname $recommended";
    zypper_call "in yast2-packager";    # make sure yast2 sw_single module installed

    script_run("yast2 sw_single; echo yast2-i-status-\$? > /dev/$serialdev", 0);
    assert_screen 'empty-yast2-sw_single', 90;

    # Check disk usage widget for not showing subvolumes (bsc#949945)
    # on SLE12SP0 hidden subvolume isn't supported
    if (!check_var('VERSION', '12')) {
        send_key "alt-e";
        wait_still_screen(1);
        send_key "alt-s";
        assert_screen 'yast2-sw_single-disk_usage';
        send_key "alt-o";
        wait_still_screen(1);
        send_key "alt-p";    # go back to search box
    }

    # Testcase according to https://fate.suse.com/318099
    # UC1:
    # Select a certain package, check that another gets selected/installed
    type_string("$pkgname\n");
    sleep 3;
    send_key "+";    # select for install
    assert_screen "$pkgname-selected-for-install", 5;

    if (!check_var('VERSION', '12')) {    #this functionality isn't avivable in SLE12SP0
        send_key "alt-p";                 # go to search box again
        for (1 .. length($pkgname)) { send_key "backspace" }
        type_string("$recommended\n");
        assert_screen "$recommended-selected-for-install", 10;

        # UC2b:
        # Given that package is not installed,
        # uncheck Dependencies/Install Recommended Packages,
        # select the package, verify that recommended package is NOT selected
        send_key "alt-d";    # Menu "Dependencies"
        assert_screen 'yast2-sw_install_recommended_packages_enabled', 60;
        send_key "alt-r";    # Submenu Install Recommended Packages

        assert_screen "$recommended-not-selected-for-install", 5;
        send_key "alt-p";    # go to search box again
        for (1 .. length($recommended)) { send_key "backspace" }
        type_string("$pkgname\n");
        assert_screen "$pkgname-selected-for-install", 10;
    }
    send_key "alt-a", 1;     # accept

    my @tags = qw(yast2-sw-packages-autoselected yast2-sw_automatic-changes yast2_console-finished);
    # Whether summary is shown depends on PKGMGR_ACTION_AT_EXIT in /etc/sysconfig/yast2
    push @tags, 'yast2-sw_shows_summary' unless get_var('YAST_SW_NO_SUMMARY');
    do {
        assert_screen(\@tags, 60);
        # automatic changes for manual selections
        if (match_has_tag('yast2-sw-packages-autoselected') or match_has_tag('yast2-sw_automatic-changes')) {
            wait_screen_change { send_key 'alt-o' };
        }
        elsif (match_has_tag('yast2-sw_shows_summary')) {
            wait_screen_change { send_key 'alt-f' };
        }
    } until (match_has_tag('yast2_console-finished'));

    wait_serial("yast2-i-status-0", 60) || die "'yast2 sw_single' didn't finish";

    $self->clear_and_verify_console;         # clear screen to see that second update does not do any more
    assert_script_run("rpm -e $pkgname");    # erase $pkgname
    script_run("echo mark yast test", 0);    # avoid zpper needle
    assert_script_run("! rpm -q $pkgname");
}

1;
# vim: set sw=4 et:
