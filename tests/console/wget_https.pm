# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: FIPS: wget
# Maintainer: dehai <dhkong@suse.com>
# Tags: tc#1461937


use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console "root-console";
    assert_script_run("rpm -q wget");
    assert_script_run("wget -c https://build.opensuse.org -O opensuse.html");
    assert_script_run("wget -c https://www.google.com -O google.html");
    assert_script_run("wget -c https://github.com -O github.html");
    for my $var (qw(opensuse.html google.html github.html)) {
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}

1;
