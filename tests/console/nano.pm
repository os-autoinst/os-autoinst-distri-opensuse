# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: nano
# Summary: Test nano editor
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use testapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    select_console('root-console');
    zypper_call('in nano');
    script_run("nano; echo nano-status-\$? > /dev/$serialdev", 0);
    $self->enter_test_text('nano');
    assert_screen('nano');
    wait_screen_change { send_key 'ctrl-x' };
    send_key 'n';
    wait_serial("nano-status-0") || die "'nano' could not finish successfully";
}

1;

