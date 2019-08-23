# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test pcre and applications using it
# - Install gcc-c++ pcre-devel
# - Download testfiles from autoinst_url
# - Compile C++t test code and run test
# - Save screenshot
# - Install php5 or 7 depending on distro
# - Run some php tests using pcre
# - Run "grep -qP '^VERSI(O?)N' /etc/os-release"
# - Cleanup test files
# Maintainer: Stephan Kulow <coolo@suse.de>

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

    my $php = (is_leap('<15.0') || is_sle('<15')) ? 'php5' : 'php7';
    zypper_call("in $php");
    assert_script_run "php simple.php | grep 'matches'";
    save_screenshot;

    assert_script_run "php complex.php | grep 'domain name is: php.net'";
    save_screenshot;

    assert_script_run "grep -qP '^VERSI(O?)N' /etc/os-release";

    # cleanup
    assert_script_run "cd; rm -rf pcre_data";
}

1;
