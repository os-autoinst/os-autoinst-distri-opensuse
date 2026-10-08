# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate user with password
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    select_console 'user-console';
}

# Overwrite post_run_hook due to no permissions from first user to go home on TTYS0
sub post_run_hook {
    my ($self) = @_;

    $self->record_avc_selinux_alerts();
    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

1;
