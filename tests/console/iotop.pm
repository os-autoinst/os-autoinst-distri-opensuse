# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iotop
# Summary: Test iotop
# - Check basic functionality of iotop
# - Run iotop in background and create some load
# - Make sure load is detected in the report
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    select_serial_terminal;
    install_package('iotop', trup_reboot => 1);

    # Test iotop with several options
    assert_script_run("iotop -bakPtn 2");

    # Test under load
    assert_script_run('(iotop -baoqn 10 > iotop.log &)');
    assert_script_run("time dd if=/dev/zero of=./file.img bs=1k count=1000000 status=none");
    assert_script_run("wait");
    assert_script_run("grep 'dd if=/dev/zero of=./file.img' iotop.log");

    # Cleanup
    assert_script_run("rm file.img iotop.log");
}

sub post_fail_hook {
    assert_script_run("cat iotop.log");
}

1;
