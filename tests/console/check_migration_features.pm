# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: SUSEConnect
# Summary: Verify migration features on target system.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use version_utils;

# SLE-21916: change bzr to breezy
# check in the upgraded sysetem that bzr was repalced by breezy
# test steps:
# 1) install the bzr as usaual
# 2) check the bzr version as usual to make sure it has breezy
# 3) cleanup by removing the package
sub check_bzr_to_breezy {
    record_info('SLE-21916', 'Check bzr to breezy');
    zypper_call('in bzr');

    assert_script_run('bzr --version');
    assert_script_run('bzr --version | grep breezy');
    zypper_call('--no-refresh info breezy');

    zypper_call("rm bzr", exitcode => [0]);
}

# SLE-20176 QA: Drop Python 2 (15 SP4)
# check in the upgraded system to ensure Python2 dropped
sub check_python2_dropped {
    my $out = script_output('zypper se python2 | grep python2', proceed_on_failure => 1);
    record_info('python2 dropped but still can be searched', 'Bug 1196533 - Python2 package still can be searched after migration to SLES15SP4', result => 'fail') if ($out =~ 'python2');
}

# SLE-23610: Python3 module
# test steps:
# 1) activate the python3 module
# 2) install the python310 package
# 3) check python3.10's version which should be 3.10.X
# 4) check python3's version
# 5) check python310's lifecycle
sub check_python3_module {
    record_info('SLE-23610', 'Check Python3 Module');
    my $OS_VERSION = script_output("grep VERSION_ID /etc/os-release | cut -c13- | head -c -2");
    my $ARCH = get_required_var('ARCH');
    assert_script_run("SUSEConnect -p sle-module-python3/$OS_VERSION/$ARCH", timeout => 180);
    zypper_call("se python310");
    zypper_call("in python310");
    assert_script_run("python3.10 --version | grep Python | grep 3.10.");
    assert_script_run("python3 --version | grep Python | grep 3.6.");
    assert_script_run("zypper lifecycle python310");
}

# function to check all the features after migration
sub check_feature {
    if (!get_var('MEDIA_UPGRADE')) {
        check_bzr_to_breezy;
        check_python3_module;
    }
    check_python2_dropped;
}

sub run {
    select_console('root-console');
    assert_script_run('setterm -blank 0') unless (is_s390x);

    check_feature;
}

1;
