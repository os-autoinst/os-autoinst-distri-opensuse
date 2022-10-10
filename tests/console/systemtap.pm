# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic systemtap functions
# * Test simple hello world
# * Test stap-server output
# * Test simple probing
# Maintainer: Anastasiadis Vasileios <vasilios.anastasiadis@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use version_utils qw(is_sle);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    prepare_for_kdump();
    zypper_call("in systemtap systemtap-docs kernel-devel systemtap-server");
    script_run('ti=$(ls /lib/modules/ | grep $(uname -r) | grep -oP ".*(?=-default)") && zypper se -i -s kernel-default-devel | grep $ti > vertmp');
    my $vers = script_output('cat vertmp');
    if (!$vers) {
        my $kernel_d = script_output('uname -r | grep -oP ".*(?=-default)"');
        my $dev = zypper_call("se -i -s kernel-default-devel", exitcode => [0, 104]);
        if ($dev ne '104') {
            die "Installed kernel-devel does not match kernel version. This usually happens when there's a new kernel, wait a day to see if the image is updated \nExpected: $kernel_d, Found: Other kernel-default-devel versions";
        } else {
            die "kernel-devel package is required but not installed\nExpected: $kernel_d, Found: No kernel-default-devel package installed";
        }
    }
    assert_script_run("stap /usr/share/doc/packages/systemtap/examples/general/helloworld.stp | grep 'hello world'", 200);
    assert_script_run("stap-server condrestart | grep --line-buffered \"managed\"");
    assert_script_run("stap -v -e 'probe vfs.read {printf(\"read performed\\n\"); exit()}'");
}

1;
