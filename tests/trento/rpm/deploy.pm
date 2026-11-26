# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Deploy Trento Server and Agent from RPM packages with ansible-trento, using TLS
# Packages: ansible-trento
# Maintainer: Trento team <trento-developers@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(random_string);
use trento::rpm;

sub run {
    select_serial_terminal;

    my $admin_password = get_var('TRENTO_ADMIN_PASSWORD');
    $admin_password = random_string(undef, 12) if (!defined $admin_password || $admin_password eq '');
    die 'TRENTO_ADMIN_PASSWORD must contain at least 8 characters' if length($admin_password) < 8;
    die 'TRENTO_ADMIN_PASSWORD must not contain single quotes, they break shell quoting' if $admin_password =~ /'/;
    # Later modules read the password to log in to Trento Web
    set_var('TRENTO_ADMIN_PASSWORD', $admin_password);

    trento_rpm_install_ansible_trento();
    trento_rpm_setup_tls();
    my $ansible_env = trento_rpm_prepare_ansible();
    trento_rpm_run_playbook(admin_password => $admin_password, ansible_env => $ansible_env);
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    record_info('Services', script_output('systemctl list-units "trento-*" nginx postgresql rabbitmq-server --no-pager', proceed_on_failure => 1));
    script_run('journalctl --no-pager -u "trento-*" -u nginx -n 300 > /tmp/trento-journal.log 2>&1');
    upload_logs('/tmp/trento-journal.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;
