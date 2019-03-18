# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: genders
#    This test is setting up a genders scenario according to the testcase
#    described in FATE 324149
# Maintainer: Petr Cervinka <pcervinka@suse.com>
# Tags: https://fate.suse.com/324149

use base 'hpcbase';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # Install genders package
    zypper_call('in genders');

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
    assert_script_run('diff $tmpfile $cfile');
}

1;
