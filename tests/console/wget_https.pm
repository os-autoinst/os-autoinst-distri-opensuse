# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wget
# Summary: FIPS: wget
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1461937


use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_text_console';
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_text_console;

    # Install runtime dependencies
    zypper_call("in wget");

    assert_script_run("rpm -q wget");
    # GitHub occasionally answers with a slow 503; retry it instead of
    # failing the module on a transient upstream error.
    my $wget_opts = '-c --tries=3 --timeout=30 --waitretry=5 --retry-on-http-error=503';
    assert_script_run("wget $wget_opts https://www.google.com -O google.html", timeout => 180);
    assert_script_run("wget $wget_opts https://github.com -O github.html", timeout => 180);
    my @files = qw(google.html github.html);
    for my $var (@files) {
        assert_script_run("test -f $var");
        assert_script_run("rm -f $var");
    }
}

1;
