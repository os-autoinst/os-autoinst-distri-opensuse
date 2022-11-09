# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Register addons in the remote system
#   Registration is in registercloudguest test module
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use version_utils;
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils;
use publiccloud::ssh_interactive "select_host_console";

sub run {
    my ($self, $args) = @_;

    $self->{instance} = $args->{my_instance};

    select_host_console();    # select console on the host, not the PC instance

    registercloudguest($args->{my_instance});
    register_addons_in_pc($args->{my_instance});
}

sub cleanup {
    my ($self) = @_;
    if (is_azure()) {
        record_info('azuremetadata', $self->{instance}->run_ssh_command(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
