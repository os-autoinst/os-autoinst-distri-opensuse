# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare UI toolkit tests
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use registration qw(add_suseconnect_product register_product);

sub run {
    select_console 'root-console';

    if (is_sle) {
        # enable sdk
        assert_script_run 'source /etc/os-release';
        if (get_var 'ADDONURL_SDK') {
            zypper_call('ar ' . get_var('ADDONURL_SDK') . ' sdk-repo');
            zypper_call('ref');
        }
        elsif (is_sle '>=15') {
            add_suseconnect_product('sle-module-development-tools');
        }
        else {
            # for historical reasons we don't register SLE12 systems in openqa by default
            register_product();
            add_suseconnect_product('sle-sdk');
        }
    }

    my $qt5_devel = 'libQt5Core-devel libQt5Gui-devel libQt5Widgets-devel';
    my $qt6_devel = 'qt6-core-devel qt6-gui-devel qt6-widgets-devel';

    zypper_call "in gcc gcc-c++ tcl tk xmessage fltk-devel motif-devel gtk2-devel gtk3-devel gtk4-devel java java-devel $qt5_devel $qt6_devel";

    if (is_opensuse) {
        # make sure to use latest java (that matches the java compiler that was just installed)
        assert_script_run 'update-alternatives --set java $(ls /usr/lib64/jvm/jre-*-openjdk/bin/java|sort|tail -1)';
    }

    select_console 'x11';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}


1;
