# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nfs nfs_v4
# Summary: Test nfs and nfs_v4
# Test scripts are extracted from package 'qa_test_nfs'
# and 'qa_lib_internalapi' with some minor changes,
# then we can run them directly.
#
# Due to poo#124541, nfs_read test may fail if the setup in heavy load
# We need to add some workaround to make sure data is writen to disk
######################################################
# $diff nfs_read_write_fn_new.sh nfs_read_write_fn.sh
#  33d32
#  <     sync; sleep 3
######################################################
# Maintainer: rfan1 <richard.fan@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub nfs_test {
    my ($nfs_ver) = @_;
    $nfs_ver //= 'nfs';
    my @test_cases
      = qw(nfs_start_stop nfs_mount_umount nfs_read nfs_write nfs_dontwrite nfs_usermapping_rootsquash nfs_usermapping_norootsquash nfs_usermapping_allsquash);
    foreach my $test_case (@test_cases) {
        record_info("$nfs_ver: $test_case");
        assert_script_run("/usr/share/qa/qa_test_nfs/run-wrapper.sh $test_case.sh $nfs_ver", timeout => 300);
    }
}

sub setup_env {
    select_serial_terminal;
    assert_script_run('wget --quiet ' . data_url('qam/nfs.tar.bz2') . ' -O /tmp/nfs.tar.bz2');
    assert_script_run('cd /usr/share; tar -xjf /tmp/nfs.tar.bz2');
    zypper_call('in yast2-nfs-server') if is_sle('>=15');
}

sub run {
    select_serial_terminal;
    setup_env();
    nfs_test();    # Test nfs
    nfs_test('nfs4');    # Test nfs_v4
}

1;
