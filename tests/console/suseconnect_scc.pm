# SUSE openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: SUSEConnect
# Summary: Register system image against SCC
# Maintainer: qac <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use registration qw(verify_scc investigate_log_empty_license runtime_registration);
use utils 'ensure_ca_certificates_suse_installed';
use version_utils 'is_staging';

sub run {
    # Development product staging jobs use repositories from download.suse.de and need the SUSE certificate
    ensure_ca_certificates_suse_installed if is_staging;
    runtime_registration();    # assume it will run in serial terminal
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license unless (script_run 'test -f /var/log/YaST2/y2log');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
