# SUSE's Django regression test
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-Django
# Summary: Test basic python3-Django
# Maintainer: qe-core@suse.de

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use version_utils qw(is_sle is_leap);
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);

sub run {
    select_serial_terminal;
    my $python_version;
    # python3-Django and various dependencies require PackageHub available
    return unless is_phub_ready();

    add_suseconnect_product("PackageHub", undef, undef, undef, 300, 1) if is_sle;
    add_suseconnect_product(get_addon_fullname('desktop'), undef, undef, undef, 300, 1) if is_sle('<=15');
    # The django package provided in SP6 is python311-Django, bsc#1221960
    if (zypper_call("se -x python311-Django", exitcode => [0, 104]) == 104) {
        zypper_call "in python3-Django";
        $python_version = "python3";
    } else {
        zypper_call("in python311-Django");
        $python_version = "python3.11";
    }
    assert_script_run 'mkdir my_django_project';
    assert_script_run 'cd my_django_project';

    assert_script_run 'django-admin startproject config .';
    assert_script_run "$python_version manage.py runserver & sleep 10";
    assert_script_run 'curl -s http://localhost:8000/ | grep "The install worked successfully"';
    assert_script_run 'kill $!';
    assert_script_run 'cd -';
}

# Removal of installed python311 and python311-Django are required as a cleanup.
# The following test(python3-new_version_check) only to list the built-in/default
# Python version(python3.6).
sub post_run_hook {
    if (is_sle('>=15-SP6') || is_leap('>=15.6')) {
        zypper_call('rm python311-Django', exitcode => [0, 104]);
        zypper_call('rm python311-base', exitcode => [0, 104]);
    }
}

sub post_fail_hook {
    if (is_sle('>=15-SP6') || is_leap('>=15.6')) {
        zypper_call('rm python311-Django', exitcode => [0, 104]);
        zypper_call('rm python311-base', exitcode => [0, 104]);
    }
}

1;

