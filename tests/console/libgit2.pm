# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Basic libgit2 test via python pygit2
# - Test should test on sle15sp6+ and tw, see https://jira.suse.com/browse/PED-7228
# - Package 'pygit2' requires Python '>=3.7'
# - Run some basic test (pygit2_test.py)
#
# Maintainer: QE Core <qe-core@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_leap);
use utils 'zypper_call';
use python_version_utils;
use registration 'add_suseconnect_product';

my $python3_version;
my $python_sub_version;

sub run {
    select_serial_terminal;
    return if (is_sle('<15-sp6') || is_leap('<15.6'));

    # Install libgit2
    if (is_sle) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
        add_suseconnect_product('sle-module-python3');
    }
    my $pkg_ver = script_output("zypper se '/^libgit2-[0-9].*[0-9]\$/' | awk -F '|' '/libgit2-[0-9]/ {gsub(\" \", \"\"); print \$2}' | uniq");
    zypper_call "in $pkg_ver libgit2-tools";
    record_info("Installed libgit2 version", script_output("rpm -q --qf '%{VERSION}\n' $pkg_ver"));

    # Install the latest python3 package
    $python3_version = get_available_python_versions('1');
    zypper_call "in $python3_version";
    $python_sub_version = substr($python3_version, 7);

    # Install pygit2
    assert_script_run "pip3.$python_sub_version install pygit2 --break-system-packages";

    # Run test script
    assert_script_run "wget --quiet " . data_url('libgit2/pygit2_test.py') . " -O pygit2_test.py";
    assert_script_run "python3.$python_sub_version pygit2_test.py";

    # Cleanup
    clean_up();
}

sub clean_up {
    assert_script_run "pip3.$python_sub_version uninstall pygit2 -y --break-system-packages";
    zypper_call "rm $python3_version";
    assert_script_run "rm -rf libgit2";
}

sub post_fail_hook {
    select_console 'log-console';
    clean_up();
}

1;
