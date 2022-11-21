# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Test system (re)registration
# https://github.com/SUSE-Enceladus/cloud-regionsrv-client/blob/master/integration_test-process.txt
# Leave system in *registered* state
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
use publiccloud::ssh_interactive 'select_host_console';
use version_utils 'is_sle';

sub run {
    my ($self, $args) = @_;

    # Preserve args for post_fail_hook
    $self->{instance} = $args->{my_instance};

    # Create $instance to make the code easier to read
    my $instance = $args->{my_instance};

    my $regcode_param = (is_byos()) ? "-r " . get_required_var('SCC_REGCODE') : '';

    select_host_console();    # select console on the host, not the PC instance

    if (is_container_host()) {
        # CHOST images don't have registercloudguest pre-installed. To install it we need to register which make it impossible to do
        # all BYOS related checks. So we just regestering system and going further
        registercloudguest($instance);
    } elsif (is_byos()) {
        if ($instance->run_ssh_command(cmd => 'sudo zypper lr', proceed_on_failure => 1) !~ /No repositories defined/gm) {
            die 'The BYOS instance should be unregistered and report "Warning: No repositories defined.".';
        }

        if ($instance->run_ssh_command(cmd => 'sudo systemctl is-enabled guestregister.service', proceed_on_failure => 1) !~ /disabled/) {
            (is_sle('=12-SP4') || is_sle('=15-sp1')) ? record_soft_failure('bsc#1199311 - guestregister.service is not disabled') : die('guestregister.service is not disabled');
        }

        if ($instance->run_ssh_command(cmd => 'sudo ls /etc/zypp/credentials.d/ | wc -l', proceed_on_failure => 1) != 0) {
            $instance->run_ssh_command(cmd => 'sudo ls -la /etc/zypp/credentials.d/', proceed_on_failure => 1);
            (is_sle('=12-SP4') || is_sle('=15-sp1')) ? record_soft_failure('bsc#1199311 - guestregister.service is not disabled') : die('/etc/zypp/credentials.d/ is not empty');
        }

        if (is_azure() && $instance->run_ssh_command(cmd => 'sudo systemctl is-enabled regionsrv-enabler-azure.timer', proceed_on_failure => 1) !~ /enabled/) {
            die('regionsrv-enabler-azure.timer is not enabled');
        }

        if ($instance->run_ssh_command(cmd => 'sudo stat --printf="%s" /var/log/cloudregister', proceed_on_failure => 1) != 0) {
            (is_sle('=12-SP4') || is_sle('=15-sp1')) ? record_soft_failure('bsc#1199311 - guestregister.service is not disabled') : die('/var/log/cloudregister is not empty');
        }
        # The `sudo SUSEConnect -d` is not supported on BYOS and should fail.
        $instance->run_ssh_command(cmd => '! sudo SUSEConnect -d');
    } else {
        if ($instance->run_ssh_command(cmd => 'sudo zypper lr | wc -l', proceed_on_failure => 1, timeout => 360) < 5) {
            record_info('zypper lr', $instance->run_ssh_command(cmd => 'sudo zypper lr', proceed_on_failure => 1));
            die 'The list of zypper repositories is too short.';
        }

        if ($instance->run_ssh_command(cmd => 'sudo systemctl is-enabled guestregister.service', proceed_on_failure => 1) !~ /enabled/) {
            die('guestregister.service is not enabled');
        }

        if ($instance->run_ssh_command(cmd => 'sudo ls /etc/zypp/credentials.d/ | wc -l', proceed_on_failure => 1) == 0) {
            die('/etc/zypp/credentials.d/ is empty');
        }

        if ($instance->run_ssh_command(cmd => 'sudo stat --printf="%s" /var/log/cloudregister', proceed_on_failure => 1) == 0) {
            die('/var/log/cloudregister is empty');
        }
    }

    # Test re-registration. Assuming the system has been registered before
    if (script_run('which registercloudguest') != 0 && (is_sle('=12-SP4') || is_sle('=15-sp1'))) {
        record_soft_failure('bsc#1198815 - Package cloud-regionsrv-client is not installed');
        registercloudguest($instance);
    } else {
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

    register_addons_in_pc($instance);
}

sub post_fail_hook {
    my ($self) = @_;
    if (is_azure()) {
        record_info('azuremetadata', $self->{instance}->run_ssh_command(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
    $self->SUPER::post_fail_hook;
    registercloudguest($self->{instance});
}

sub test_flags {
    return {fatal => 0, publiccloud_multi_module => 1};
}

1;
