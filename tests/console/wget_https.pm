# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1461937 - FIPS: wget

use base "consoletest";
use strict;
use testapi;

sub run() {

    select_console "root-console";
    assert_script_run("rpm -q wget");
    assert_script_run("wget -c https://build.opensuse.org -O opensuse.html");
    wait_still_screen;
    assert_script_run("wget -c https://www.google.com -O google.html");
    wait_still_screen;
    assert_script_run("wget -c https://github.com -O github.html");
    wait_still_screen;
    for my $var (qw/opensuse.html google.html github.html/){
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}
1;
# vim: set sw=4 et:
