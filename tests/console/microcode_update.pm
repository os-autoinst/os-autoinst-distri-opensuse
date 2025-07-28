# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: ucode-intel ucode-amd
# Summary: Test microcode update on bare-metal (ipmi backend)
#          Install ucode package if not installed
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use utils 'zypper_call';
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my ($self, $vendor, $match) = @_;
    use_ssh_serial_console;
    # different true exit status value bash 0 perl 1
    if (script_run 'lscpu|grep -i intel') {
        $vendor = 'amd';
        # on amd is no dmesg message which would prove or disprove microcode update
        $match = 'microcode';
    }
    else {
        $vendor = 'intel';
        $match = 'microcode updated';
    }
    # different true exit status value bash 0 perl 1
    unless (script_run "zypper if ucode-$vendor|grep 'not installed'") {
        zypper_call "in ucode-$vendor";
        console('root-ssh')->kill_ssh;
        enter_cmd "reboot";
        $self->wait_boot;
        use_ssh_serial_console;
    }
    # verify microcode is loaded in initramfs and check dmesg
    assert_script_run "lsinitrd|grep microcode|grep -i $vendor";
    assert_script_run "dmesg|grep '$match'";
}

1;
