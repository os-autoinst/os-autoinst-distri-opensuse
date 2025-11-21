# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Register addons in the remote system
#   Registration is in registercloudguest test module
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use version_utils;
use registration;
use testapi;
use utils;
use publiccloud::utils;
use publiccloud::ssh_interactive "select_host_console";
use File::Basename 'basename';

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    wait_quit_zypper_pc($args->{my_instance});

    registercloudguest($args->{my_instance}) if (is_byos() || get_var('PUBLIC_CLOUD_FORCE_REGISTRATION'));
    register_addons_in_pc($args->{my_instance});
    # Since SLE 15 SP6 CHOST images don't have curl and we need it for testing
    if (is_sle('>15-SP5') && is_container_host()) {
        $args->{my_instance}->zypper_remote_call("sudo zypper -n in --force-resolution -y curl");
    }
}

sub cleanup {
    my ($self) = @_;
    if (is_azure()) {
        record_info('azuremetadata', $self->{run_args}->{my_instance}->run_ssh_command(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
    1;
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
