# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh
# Summary: This tests will deploy the public cloud instance, create user,
#   prepare ssh config and permit password login
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive qw(select_host_console prepare_ssh_tunnel);
use testapi;
use version_utils;
use utils;
use publiccloud::utils;

sub run {
    my ($self, $args) = @_;

    # If someone schedules a publiccloud run with a custom SCHEDULE this causes
    # the test to break, because we need to pass $args, so dying earlier and with clear message about root cause
    die('Note: Running publiccloud with a custom SCHEDULE is not supported') if (!defined $args);

    select_host_console();    # select console on the host, not the PC instance

    # Prevent kernel messages of the helper VM to contaminate the serial console
    # this is needed on our ext4-based helper VM to avoid kernel messages from overlayfs
    # to confuse openQA
    assert_script_run("dmesg -n emerg");

    my $additional_disk_size = get_var('PUBLIC_CLOUD_HDD2_SIZE', 0);
    my $additional_disk_type = get_var('PUBLIC_CLOUD_HDD2_TYPE', '');    # Optional variable, also if PUBLIC_CLOUD_HDD2_SIZE is set

    # Create public cloud instance
    my $provider = $self->provider_factory();
    my %instance_args;
    $instance_args{check_connectivity} = 1;
    $instance_args{use_extra_disk} = {size => $additional_disk_size, type => $additional_disk_type} if ($additional_disk_size > 0);
    my $instance = $provider->create_instance(%instance_args);
    $instance->wait_for_guestregister();
    $args->{my_provider} = $provider;
    $args->{my_instance} = $instance;
    $instance->ssh_opts("");    # Clear $instance->ssh_opts which ombit the known hosts file and strict host checking by default

    $instance->network_speed_test();

    # ssh-tunnel settings
    prepare_ssh_tunnel($instance) if (is_tunneled());

    apply_workarounds($self, $args, $instance);
}

sub apply_workarounds {
    # This subroutine applies all workaround that are needed

    my ($self, $args, $instance) = @_;

    # 1. sudo workaround
    # azure images based on sle12-sp{4,5} code streams come with commented entries 'Defaults targetpw' in /etc/sudoers
    # because the Azure Linux agent creates an entry in /etc/sudoers.d for users without the NOPASSWD flag
    # this is an exception in comparision with other images
    if (is_sle('<15') && is_azure) {
        $instance->ssh_assert_script_run(q(sudo sed -i "/Defaults targetpw/s/^#//" /etc/sudoers));
    }

    # 2. Workaround for bsc#1205044:
    # Fix SUSEConnect to version 0.3.32 on SLES 12-SP4 and 12-SP5
    if (is_sle(">=12-SP4") && is_sle("<=12-SP5")) {
        record_info("workaround bsc#1205044", "Applying workaround for bsc#1205044");
        assert_script_run("zypper addlock SUSEConnect=0.3.32");
    }
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

1;
