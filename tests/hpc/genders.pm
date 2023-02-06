# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: genders
#    This test is setting up a genders scenario according to the testcase
#    described in FATE 324149
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/324149

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use lockapi;
use utils;

our $file = 'tmpresults.xml';

sub run ($self) {
    # Install genders package
    my $rt = zypper_call('in genders');
    test_case('Installation', 'install genders', $rt);

    # Prepare genders file`
    assert_script_run('echo "test1 test=foo" >> /etc/genders');
    assert_script_run('echo "test2 test=bar" >> /etc/genders');
    assert_script_run('echo "test3 testhost" >> /etc/genders');

    # Create test files
    assert_script_run('export tmpfile=$(mktemp /tmp/tmp-XXXXXX)');
    assert_script_run('export cfile=$(mktemp /tmp/tmp-XXXXX)');
    assert_script_run('echo -en "test1,test2\ntest1\ntest[1-2]\ntest1\ntest2\ntest[1,3]\n" > $cfile');

    # Use nodeattr to fill tmpfile
    assert_script_run('nodeattr -c test >> $tmpfile');
    assert_script_run('nodeattr -c test=foo >> $tmpfile');
    assert_script_run('nodeattr -q test >> $tmpfile');
    assert_script_run('nodeattr -n test >> $tmpfile');
    assert_script_run('nodeattr -q "test=foo||testhost" >> $tmpfile');

    # Show content of files
    assert_script_run('cat $tmpfile');
    assert_script_run('cat $cfile');

    # Compare test files, file must have same content, difference means test failure
    $rt = assert_script_run('diff $tmpfile $cfile');
    test_case('Compare test files', 'genders smoke test', $rt);
}

sub post_run_hook ($self) {
    pars_results('HPC genders tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}

1;
