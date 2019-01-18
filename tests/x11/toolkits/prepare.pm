# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare UI toolkit tests
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

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
            assert_script_run 'SUSEConnect -p sle-module-development-tools/${VERSION_ID}/${CPU}';
        }
        else {
            # for historical reasons we don't register SLE12 systems in openqa by default
            assert_script_run 'SUSEConnect -r ' . get_required_var('SCC_REGCODE');
            assert_script_run 'SUSEConnect -p sle-sdk/${VERSION_ID}/${CPU}';
        }
    }

    my $qt5_devel = 'libQt5Core-devel libQt5Gui-devel libQt5Widgets-devel';

    zypper_call "in gcc gcc-c++ tcl tk xmessage fltk-devel motif-devel gtk2-devel gtk3-devel java-devel $qt5_devel";

    if (is_opensuse) {
        zypper_call 'in libqt4-devel';
    }

    select_console 'user-console';
    assert_script_run 'cd data';
    assert_script_run 'tar xvf toolkits.tar.gz';

    select_console 'x11';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}


1;
