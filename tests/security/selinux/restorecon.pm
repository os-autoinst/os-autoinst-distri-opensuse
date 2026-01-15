# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# restorecon" to do file system labeling
# Maintainer: QE Security <none@suse.de>
# Tags: poo#65672, tc#1741291

use base "selinuxtest";
use power_action_utils "power_action";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = shift;
    my $test_dir = "/tmp/testdir";
    my $test_file = "testfile";
    my $fcontext_type1 = "etc_t";
    my $fcontext_type2 = "bin_t";

    select_serial_terminal;

    # create a testing directory/file
    $self->create_test_file("$test_dir", "$test_file");

    # label system: testing "-R / -P / -V"
    script_run("restorecon -Rp /", 600);
    script_run("restorecon -Rp /*", 600);
    script_run("restorecon -Rv /", 600);
    script_run("restorecon -Rv /*", 600);

    # clean up in case: remove all local customizations
    assert_script_run("semanage fcontext -D");

    # add local customizations
    assert_script_run("semanage fcontext -a -t $fcontext_type1 $test_dir");
    assert_script_run("semanage fcontext -a -t $fcontext_type2 ${test_dir}/${test_file}");

    # run "# restorecon -R" to label test dir/file
    assert_script_run("restorecon -R $test_dir");
    assert_script_run("restorecon -R $test_dir/*");
    validate_script_output("ls -Zd $test_dir", sub { m/$fcontext_type1/ });
    validate_script_output("ls -Z ${test_dir}/${test_file}", sub { m/$fcontext_type2/ });

    # clean up: remove all local customizations
    assert_script_run("semanage fcontext -D");
    if (is_sle('=15-SP6') || is_sle('=15-SP7')) {
        # https://progress.opensuse.org/issues/194768
        assert_script_run("semanage fcontext -a -t lib_t '/usr/lib(64)?/systemd/libsystemd.+'");
        assert_script_run("restorecon -vR /usr/lib/systemd /usr/lib64/systemd");
    }
}

1;
