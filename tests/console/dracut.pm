# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dracut
# Summary: Test dracut installation and verify that it works as expected
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use strict;
use warnings;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    assert_script_run("rpm -q dracut");

    validate_script_output("lsinitrd", sub { m/Image:(.*\n)+( ?)Version: dracut(-|\d+|\.|\+|\w+)+(\n( ?))+( ?)Arguments(.*\n)+( ?)dracut modules:(\w+|-|\d+|\n|( ?))+\=+\n(l|d|r|w|x|-|( ?))+\s+\d+ root\s+root(.*\n)+( ?)\=+/ });
    validate_script_output("dracut -f 2>&1", sub { m/.*Executing: \/usr\/bin\/dracut -f\n|\b(?:Skipping|Including modules done|Including|Creating image|Creating initramfs)\b/ }, 180);
    validate_script_output("dracut --list-modules 2>&1", sub { m/.*Executing: \/usr\/bin\/dracut --list-modules\n(\w+|\n|-|d+)+/ });

    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 200);
}

1;
