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

    select_host_console();    # select console on the host, not the PC instance

    if (is_ondemand) {
        # on OnDemand image we use `registercloudguest` to register and configure the repositories
        $args->{my_instance}->retry_ssh_command("sudo registercloudguest", timeout => 420, retry => 3);
    } else {
        my @addons = split(/,/, get_var('SCC_ADDONS', ''));
        my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;
        registercloudguest($args->{my_instance});
        for my $addon (@addons) {
            next if ($addon =~ /^\s+$/);
            register_addon($remote, $addon);
        }
    }
    record_info('LR', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper lr || true"));
    record_info('LS', $args->{my_instance}->run_ssh_command(cmd => "sudo zypper ls || true"));
}

1;
