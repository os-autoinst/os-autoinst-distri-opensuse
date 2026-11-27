# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run the Trento Web Cypress tests against the Trento Server deployed from RPM packages
# Packages: trento-web
# Maintainer: Trento team <trento-developers@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use trento::rpm;

sub run {
    select_serial_terminal;

    trento_rpm_run_cypress(
        admin_password => get_var('TRENTO_ADMIN_PASSWORD'),
        admin_user => get_var('TRENTO_ADMIN_USER', 'admin'),
        # TODO: temporary, run only the about spec while testing. Restore get_var('TRENTO_CYPRESS_SPEC', '')
        spec => 'cypress/e2e/about.cy.js');
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    script_run('journalctl --no-pager -u "trento-*" -u nginx -n 300 > /tmp/trento-journal.log 2>&1');
    upload_logs('/tmp/trento-journal.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;
