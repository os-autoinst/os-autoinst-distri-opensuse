# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wget
# Summary: FIPS: wget
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1461937


use base "consoletest";
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_console "root-console";

    # Install runtime dependencies
    zypper_call("in wget");

    assert_script_run("rpm -q wget");
    assert_script_run("wget -c https://www.google.com -O google.html");
    assert_script_run("wget -c https://github.com -O github.html");
    my @files = qw(google.html github.html);
    for my $var (@files) {
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}

1;
