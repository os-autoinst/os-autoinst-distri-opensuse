# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare the SUT for early panics
# Maintainer: Santiago Zarate <santiago.zarate+github@suse.com>
package early_test_setup;
use base 'consoletest';
use strict;
use warnings;
use testapi;

sub change_panic_behavior {
    my ($self, %args) = @_;

    # Let's enable kernel.softlockup_panic, so that we're sure
    # that whenever there's a softlockup in the kernel, there's at least
    # that backtrace in the serial console

    assert_script_run('cat /proc/cmdline');
    assert_script_run('sysctl kernel.softlockup_panic');
    assert_script_run('sysctl -w kernel.softlockup_panic=1');
    assert_script_run('sysctl -p');

}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    change_panic_behavior;
}

1;
