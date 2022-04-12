# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gcc-c++ pcre-devel
# Summary: Test pcre and applications using it
# - Install gcc-c++ pcre-devel
# - Download testfiles from autoinst_url
# - Compile C++t test code and run test
# - Save screenshot
# - Install php? depending on distro
# - Run some php tests using pcre
# - Run "grep -qP '^VERSI(O?)N' /etc/os-release"
# - Cleanup test files
# Maintainer: QE-Core <qe-core@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_leap is_sle);

sub run {
    select_console 'root-console';
    zypper_call("in gcc-c++ pcre-devel");
    assert_script_run "mkdir pcre_data; cd pcre_data; curl -L -v " . autoinst_url . "/data/pcre > pcre-tests.data && cpio -id < pcre-tests.data && cd data";
    assert_script_run "ls .";
    assert_script_run "g++ pcretest.cpp -o test_pcrecpp -lpcrecpp";
    assert_script_run "./test_pcrecpp";
    save_screenshot;

    my $php = '';
    if (is_leap('<15.0') || is_sle('<15')) {
        $php = 'php5';
    }
    elsif (is_leap("<15.4") || is_sle("<15-SP4")) {
        $php = 'php7';
    }
    else {
        $php = 'php8';
    }
    zypper_call("in $php");
    assert_script_run "$php simple.php | grep 'matches'";
    save_screenshot;

    assert_script_run "$php complex.php | grep 'domain name is: php.net'";
    save_screenshot;

    assert_script_run "grep -qP '^VERSI(O?)N' /etc/os-release";

    # cleanup
    assert_script_run "cd; rm -rf pcre_data";
}

1;
