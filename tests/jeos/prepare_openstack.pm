# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: JeOS OpenStack image validation
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use publiccloud::ssh_interactive "select_host_console";

sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance(check_guestregister => 0);
    $self->{provider} = $args->{my_provider} = $provider;
    $args->{my_instance} = $instance;
    $args->{ssh_log_file} = '/var/tmp/ssh_sut.log';
    $args->{instance_host_alias} = 'sut';

    # instance settings
    $instance->run_ssh_command(cmd => q[sudo sed -i 's/^no.*ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys], no_quote => 1);
    $instance->run_ssh_command(cmd => q[sudo cat /root/.ssh/authorized_keys]);
    $instance->run_ssh_command(cmd => qq[sudo mkdir -p /home/$testapi::username/.ssh/]);
    $instance->run_ssh_command(cmd => qq[sudo install -m 600 /root/.ssh/authorized_keys /home/$testapi::username/.ssh/authorized_keys]);
    $instance->run_ssh_command(cmd => qq[sudo chown $testapi::username:users /home/$testapi::username/.ssh/authorized_keys]);
    $instance->run_ssh_command(cmd => qq[rpm -q cloud-init]);
    $instance->ssh_opts("");
    # helper VM settings
    assert_script_run(sprintf(q(echo -e 'Host %s\n  Hostname %s' >> ~/.ssh/config), $args->{instance_host_alias}, $instance->public_ip));
    assert_script_run "install -m 666 /dev/null $args->{ssh_log_file}";
    assert_script_run 'mkdir /home/bernhard/.ssh/';
    assert_script_run("install -o $testapi::username -g users -m 0600 ~/.ssh/* /home/$testapi::username/.ssh/");
    assert_script_run 'cat /home/bernhard/.ssh/id_rsa';
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

1;
