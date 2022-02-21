# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: JeOS OpenStack image validation
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();

    record_info('Uname', $instance->run_ssh_command(cmd => q(uname -a)));
    $instance->run_ssh_command(cmd => 'sudo journalctl -b > /tmp/journalctl_b.txt', no_quote => 1);
    upload_logs('/tmp/journalctl_b.txt');
}

1;
