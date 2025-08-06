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
use registration qw(add_suseconnect_product is_phub_ready);

my $python_sub_version;

sub run {
    # Package 'pygit2' requires PackageHub is available
    return if (!is_phub_ready() && is_sle('<16'));

    select_serial_terminal;
    return if (is_sle('<15-sp6') || is_leap('<15.6'));

    if (is_sle('<16')) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
        add_suseconnect_product('sle-module-python3');
    }

    # Install the latest pygit2
    my @pygit2_versions = split(/\n/, script_output(qq[zypper se '/^python3[0-9]{1,2}-pygit2\$/' | awk -F '|' '/python3[0-9]{1,2}/ {gsub(" ", ""); print \$2}' | uniq]));
    die 'Cannot find any verisons of pygit2' unless (@pygit2_versions);
    record_info("Available versions", "All available new pygit2 versions are: @pygit2_versions");
    record_info("The latest version is:", "$pygit2_versions[$#pygit2_versions]");

    zypper_call "in $pygit2_versions[$#pygit2_versions]";

    # Run test script
    assert_script_run "wget --quiet " . data_url('libgit2/pygit2_test.py') . " -O pygit2_test.py";
    my @pkg_version = split(/-/, $pygit2_versions[$#pygit2_versions]);
    $python_sub_version = substr($pkg_version[0], 7);
    assert_script_run "python3.$python_sub_version pygit2_test.py";

    # Cleanup
    clean_up();
}

sub clean_up {
    zypper_call "rm python3$python_sub_version-pygit2";
    my $out = script_output "python3.$python_sub_version pygit2_test.py", proceed_on_failure => 1;
    zypper_call "rm python3$python_sub_version";
    assert_script_run "rm -rf libgit2";
    die("uninstalling of python3$python_sub_version-pygit2 failed") if (index($out, "ModuleNotFoundError") == -1);
}

sub post_fail_hook {
    select_console 'log-console';
    clean_up();
}

1;
