# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test microcode update on bare-metal (ipmi backend)
#          Install ucode package if not installed
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use base 'consoletest';
use testapi;
use utils 'zypper_call';
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my ($self, $vendor) = @_;
    use_ssh_serial_console;
    # different true exit status value bash 0 perl 1
    if (script_run 'lscpu|grep -i intel') {
        $vendor = 'amd';
    }
    else {
        $vendor = 'intel';
    }
    # different true exit status value bash 0 perl 1
    unless (script_run "zypper if ucode-$vendor|grep 'not installed'") {
        zypper_call "in ucode-$vendor";
        console('root-ssh')->kill_ssh;
        type_string "reboot\n";
        $self->wait_boot;
        use_ssh_serial_console;
    }
    assert_script_run 'dmesg|grep "microcode updated"';
}

1;
