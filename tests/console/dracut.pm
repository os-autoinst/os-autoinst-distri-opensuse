# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test dracut installation and verify that it works as expected
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    assert_script_run("rpm -q dracut");

    validate_script_output("lsinitrd", sub { m/Image:(.*\n)+( ?)Version: dracut(-|\d+|\.|\w+)+(\n( ?))+( ?)Arguments(.*\n)+( ?)dracut modules:(\w+|-|\d+|\n|( ?))+\=+\n(l|d|r|w|x|-|( ?))+\s+\d+ root\s+root(.*\n)+( ?)\=+/ });
    validate_script_output("dracut -f", sub { m/.*Executing: \/usr\/bin\/dracut -f\n|\b(?:Skipping|Including modules done|Including|Creating image|Creating initramfs)\b/ });
    validate_script_output("dracut --list-modules", sub { m/.*Executing: \/usr\/bin\/dracut --list-modules\n(\w+|\n|-|d+)+/ });

    power_action('reboot', textmode => 1);
    $self->wait_boot;
}

1;
