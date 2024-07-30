# SUSE's openQA tests#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Preparation before provisioning NFS setup
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use utils;
use lockapi;

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');

    select_serial_terminal;
    systemctl 'stop ' . $self->firewall;
    set_hostname(get_var("HOSTNAME", "susetest"));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
sub post_run_hook { }

1;
