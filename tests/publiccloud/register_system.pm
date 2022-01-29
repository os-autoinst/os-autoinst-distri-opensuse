# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Register the remote system
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use version_utils;
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils;

sub run {
    my ($self, $args) = @_;

    # Preserve args for post_fail_hook
    $self->{instance} = $args->{my_instance};

    select_host_console();    # select console on the host, not the PC instance

    # The OnDemand (PAYG) images should be registered
    # automatically by the guestregister.service
    if (!is_ondemand()) {
        my @addons = split(/,/, get_var('SCC_ADDONS', ''));
        my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;
        registercloudguest($args->{my_instance});
        for my $addon (@addons) {
            next if ($addon =~ /^\s+$/);
            register_addon($remote, $addon);
        }
    }
    record_info('repos (lr)', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper lr"));
    record_info('repos (ls)', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper ls"));
}

sub post_fail_hook {
    my ($self) = @_;
    $self->{instance}->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
    $self->SUPER::post_fail_hook;
}

1;
