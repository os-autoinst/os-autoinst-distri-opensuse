# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-metapackage-handler
# Summary: Test OneClickInstallCLI and OneClickInstallUI
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

use y2_module_consoletest;

sub run {
    # Prerequisites
    my $url_ymp = 'https://software.opensuse.org/ymp/openSUSE:Factory/standard/xosview.ymp';
    select_console('root-console');
    assert_script_run('which OneClickInstallCLI || zypper -n in yast2-metapackage-handler', 200);
    assert_script_run("which OneClickInstallUI");

    # Validate OneClickInstallCLI
    assert_script_run('yes | OneClickInstallCLI ' . $url_ymp . ' || [ "$?" = "141" ]', 200);
    assert_script_run('which xosview');

    # Remove package
    zypper_call('rm xosview');

    # Validate OneClickInstallUI: it is just a simple wrapper script
    # calling the yast module, should suffice to run the module directly
    my $module_name = y2_module_consoletest::yast2_console_exec(
        yast2_module => 'OneClickInstallUI', args => $url_ymp);
    assert_screen('yast2_OneClickInstallUI_description');
    send_key($cmd{next});
    assert_screen('yast2_OneClickInstallUI_proposal');
    send_key($cmd{next});
    assert_screen('yast2_OneClickInstallUI_warning');
    send_key('alt-y');
    assert_screen('yast2_OneClickInstallUI_summary');
    send_key($cmd{finish});
    wait_serial("$module_name-0", 240) || die "'OneClickInstallUI' didn't finish";
    assert_script_run('which xosview');
}

1;
