# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test pcre and applications using it
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use base "consoletest";
use testapi;
use utils;

sub run() {
    select_console 'root-console';
    zypper_call("in gcc-c++ pcre-devel");
    assert_script_run "cd; curl -L -v "
      . autoinst_url
      . "/data/pcre > pcre-tests.data && cpio -id < pcre-tests.data && mv data pcre && cd pcre && ls .";
    assert_script_run "g++ pcretest.cpp -o test_pcrecpp -lpcrecpp";
    assert_script_run "./test_pcrecpp";
    save_screenshot;

    zypper_call("in php5");
    assert_script_run "php simple.php | grep 'matches'";
    save_screenshot;

    assert_script_run "php complex.php | grep 'domain name is: php.net'";
    save_screenshot;

    assert_script_run "grep -qP '^VERSI(O?)N' /etc/os-release";
}

1;
# vim: set sw=4 et:
