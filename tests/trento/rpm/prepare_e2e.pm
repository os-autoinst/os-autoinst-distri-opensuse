# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare the Trento Server deployed from RPM packages for the Cypress end-to-end tests
# Packages: trento-web trento-wanda trento-agent
# Maintainer: Trento team <trento-developers@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use trento::rpm;

sub run {
    select_serial_terminal;

    my $admin_password = get_var('TRENTO_ADMIN_PASSWORD');
    trento_rpm_prepare_e2e(admin_password => $admin_password, admin_user => get_var('TRENTO_ADMIN_USER', 'admin'));
    trento_rpm_setup_cypress();
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    script_run('journalctl --no-pager -u "trento-*" -u nginx -u postgresql -n 300 > /tmp/trento-journal.log 2>&1');
    upload_logs('/tmp/trento-journal.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;
