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
use publiccloud::ssh_interactive "select_host_console";
use testapi;
use utils;

sub prepare_ssh_tunnel {
    my $instance = shift;

    # configure ssh client
    my $ssh_config_url = data_url('publiccloud/ssh_config');
    assert_script_run("curl $ssh_config_url -o ~/.ssh/config");

    # Create the ssh alias
    assert_script_run(sprintf(q(echo -e 'Host sut\n  Hostname %s' >> ~/.ssh/config), $instance->public_ip));

    # Copy SSH settings also for normal user
    assert_script_run("install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    assert_script_run("install -o $testapi::username -g users -m 0600 ~/.ssh/* /home/$testapi::username/.ssh/");

    # Skip setting root password for img_proof, because it expects the root password to NOT be set
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd root));

    # Permit root passwordless login over SSH
    $instance->ssh_assert_script_run('sudo sed -i "s/PermitRootLogin no/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config');
    $instance->ssh_assert_script_run('sudo systemctl reload sshd');

    # Copy SSH settings for remote root
    $instance->ssh_assert_script_run('sudo install -o root -g root -m 0700 -dD /root/.ssh');
    $instance->ssh_assert_script_run(sprintf("sudo install -o root -g root -m 0644 /home/%s/.ssh/authorized_keys /root/.ssh/", $instance->{username}));

    # Create remote user and set him a password
    $instance->ssh_assert_script_run("test -d /home/$testapi::username || sudo useradd -m $testapi::username");
    $instance->ssh_assert_script_run(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd $testapi::username));

    # Copy SSH settings for remote user
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    $instance->ssh_assert_script_run("sudo install -o $testapi::username -g users -m 0644 ~/.ssh/authorized_keys /home/$testapi::username/.ssh/");

    # Create log file for ssh tunnel
    my $ssh_sut = '/var/tmp/ssh_sut.log';
    assert_script_run "touch $ssh_sut; chmod 777 $ssh_sut";
}

sub run {
    my ($self, $args) = @_;

    # If someone schedules a publiccloud run with a custom SCHEDULE this causes
    # the test to break, because we need to pass $args, so dying earlier and with clear message about root cause
    die('Note: Running publiccloud with a custom SCHEDULE is not supported') if (!defined $args);

    select_host_console();    # select console on the host, not the PC instance

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
    prepare_ssh_tunnel($instance) if (get_var('TUNNELED'));
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

1;
