# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1461937 - FIPS: wget

# G-Summary: Add Case 1461937-FIPS: wget and modify main.pm
#    Need enable FIPS environment before test this script.
#    Impact the openssl module
# G-Maintainer: dehai <dhkong@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run() {

    select_console "root-console";
    assert_script_run("rpm -q wget");
    assert_script_run("wget -c https://build.opensuse.org -O opensuse.html");
    assert_script_run("wget -c https://www.google.com -O google.html");
    assert_script_run("wget -c https://github.com -O github.html");
    for my $var (qw/opensuse.html google.html github.html/) {
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
