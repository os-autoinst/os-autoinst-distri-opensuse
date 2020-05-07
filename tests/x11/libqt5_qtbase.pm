# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: libqt5-qtbase: testing of the qtbase libraries
# - Install and launch Qt Designer
# - Create default UI elements, run design preview
# - Open Yast2 release notes (that uses Qt)
# - Compile and launch an app - tests qmake, QtNetwork features etc
# Maintainer: Timo Jyrinki <tjyrinki@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'ensure_unlocked_desktop';
use version_utils 'is_sle';
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);

sub run {
    my $self = shift;

    # Install required packages
    # designer-qt5 is in package libqt5-qttools, yast release notes in yast2-installation
    # SDK needs to be added for 12
    if (is_sle('<=12-SP5')) {
        select_console 'root-console';
        cleanup_registration;
        register_product;
        add_suseconnect_product(get_addon_fullname('sdk'));
    }
    select_console 'x11';
    ensure_unlocked_desktop;
    ensure_installed("libqt5-qttools yast2-installation", timeout => 180);

    # Test designer-qt5
    x11_start_program('designer-qt5');
    wait_still_screen 3;
    assert_and_click("designer-qt5-start");
    assert_screen("designer-qt5-main");
    wait_screen_change { send_key "ctrl-r" };    # run the design preview
    assert_screen("designer-qt5-preview");
    send_key "alt-f4";                           # close preview
    send_key "alt-f4";                           # close program

    # Test release notes
    x11_start_program('/usr/sbin/yast2 inst_release_notes', target_match => 'inst_release_notes');
    send_key "alt-l";                            # make sure it was closed ('Close' button shortcut)
    send_key "alt-f4";                           # close program

    # Compile an application and run it, check that exits with 0
    ensure_installed "gcc gcc-c++ libQt5Core-devel libQt5Gui-devel libQt5Network-devel libQt5Widgets-devel", timeout => 180;

    x11_start_program('xterm');
    assert_script_run 'cd data';
    assert_script_run 'tar xvf libqt5-qtbase.tar.gz';
    assert_script_run 'cd libqt5-qtbase';
    assert_script_run 'qmake-qt5';
    assert_script_run 'make';
    assert_script_run './libqt5-qtbase';
    type_string "exit\n";
}

sub post_fail_hook {
    my ($self) = @_;
}

1;
