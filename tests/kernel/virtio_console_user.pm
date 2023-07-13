# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test switching virtio root-virtio-terminal and user-virtio-terminal.
# Maintainer: Petr Vorel <pvorel@suse.cz>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;

    record_info('root user');
    select_serial_terminal;
    record_info('getty', script_output('systemctl | grep serial-getty'));
    assert_script_run('id');

    record_info('non-root user');
    select_serial_terminal(0);
    assert_script_run('id');

    record_info('root user');
    select_serial_terminal;
    assert_script_run('id');

    record_info('non-root user');
    select_serial_terminal(0);
    assert_script_run('id');
}

1;

=head1 Configuration
See virtio_console.pm.

=cut
