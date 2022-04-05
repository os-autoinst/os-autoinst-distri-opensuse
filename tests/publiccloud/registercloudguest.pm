# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Test system (re)registration
# https://github.com/SUSE-Enceladus/cloud-regionsrv-client/blob/master/integration_test-process.txt
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

sub run {
    my ($self, $args) = @_;

    # Preserve args for post_fail_hook
    $self->{instance} = $args->{my_instance};

    # Create $instance to make the code easier to read
    my $instance = $args->{my_instance};

    my $regcode = (is_byos()) ? get_required_var('SCC_REGCODE') : undef;
    my $regcode_param = ($regcode) ? "-r $regcode" : '';

    select_host_console();    # select console on the host, not the PC instance

    # Test re-registration. Assuming the system has been registered before
    # The `sudo SUSEConnect -d` is not supported on BYOS and should fail.
    $instance->run_ssh_command(cmd => '! sudo SUSEConnect -d') if (is_byos());
    $instance->run_ssh_command(cmd => 'sudo registercloudguest --clean');
    if ($instance->run_ssh_command(cmd => 'sudo zypper lr | wc -l', timeout => 600, proceed_on_failure => 1) > 2) {
        die('The list of zypper repositories is not empty.');
    }
    if ($instance->run_ssh_command(cmd => 'sudo ls /etc/zypp/credentials.d/* | wc -l', proceed_on_failure => 1) != 0) {
        die('Directory /etc/zypp/credentials.d/ is not empty.');
    }

    # The SUSEConnect registration should still work on BYOS
    if (is_byos()) {
        $instance->run_ssh_command(cmd => 'sudo SUSEConnect --version');
        $instance->run_ssh_command(cmd => "sudo SUSEConnect $regcode_param");
        $instance->run_ssh_command(cmd => 'sudo registercloudguest --clean');
    }

    $instance->run_ssh_command(cmd => "sudo registercloudguest $regcode_param");
    if ($instance->run_ssh_command(cmd => 'sudo zypper lr | wc -l', timeout => 600) == 0) {
        die('The list of zypper repositories is empty.');
    }
    if ($instance->run_ssh_command(cmd => 'sudo ls /etc/zypp/credentials.d/* | wc -l') == 0) {
        die('Directory /etc/zypp/credentials.d/ is empty.');
    }

    $instance->run_ssh_command(cmd => "sudo registercloudguest $regcode_param --force-new");
    if ($instance->run_ssh_command(cmd => 'sudo zypper lr | wc -l', timeout => 600) == 0) {
        die('The list of zypper repositories is empty.');
    }
    if ($instance->run_ssh_command(cmd => 'sudo ls /etc/zypp/credentials.d/* | wc -l') == 0) {
        die('Directory /etc/zypp/credentials.d/ is empty.');
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->{instance}->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
    if (is_azure()) {
        record_info('azuremetadata', $self->{instance}->run_ssh_command(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
    $self->SUPER::post_fail_hook;
}

1;
