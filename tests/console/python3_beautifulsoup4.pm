# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: python3-beautifulsoup tests
# - install python-beautifulsoup package
# - use library to parse sample htmlfile
# - Compare the result vs expected
#
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use warnings;
use strict;
use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use python_version_utils;


sub test_setup {
    select_serial_terminal;
    # Import python script and sample html file
    assert_script_run("curl -O " . data_url("python/bs4/python3-beautifulsoup4-test.py"));
    assert_script_run("curl -O " . data_url("python/bs4/testpage.html"));
}

sub run_test ($python_package) {
    # we don't run the test if beautifulsoup4 is not packaged for this python version
    return unless script_run("zypper search $python_package-beautifulsoup4") == 0;
    record_info("Testing for $python_package");
    zypper_call("install $python_package $python_package-beautifulsoup4 $python_package-lxml");
    my $python_interpreter = get_python3_binary($python_package);
    record_info("running python version", script_output("$python_interpreter --version"));
    # Execute python script. The script itself ensure output is the one expected
    assert_script_run("$python_interpreter python3-beautifulsoup4-test.py");
    # clean up for the next run
    zypper_call("rm $python_package $python_package-beautifulsoup4 $python_package-lxml");
}

sub run {
    my $self = shift;
    test_setup;
    my @python3_versions = get_available_python_versions();
    unshift @python3_versions, "python3";    # append the system default one
    run_test($_) foreach @python3_versions;
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup {
    remove_installed_pythons();
    script_run("rm -f python3-beautifulsoup4-test.py testpage.html");
}

1;
