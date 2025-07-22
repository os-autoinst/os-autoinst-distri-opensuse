# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that SELinux is running in permissive mode
# Maintainer: QE C <qe-c@suse.de>

use testapi;
use base "selinuxtest";

sub run {
    my ($self) = @_;

    die "SELinux is not running in permissive mode" unless $self->is_selinux_permissive();
}

1;
