# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This tests will deploy the public cloud instance and prepare the ssh
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;

    # The tunnel-console will be ocupated by the SSH tunnel
    select_console 'tunnel-console';

    # Create public cloud instance
    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance(check_connectivity => 1);
    $instance->wait_for_guestregister();
    $args->{my_provider} = $provider;
    $args->{my_instance} = $instance;

    # configure ssh client, fetch the instance ssh public key, do not use default $instance->ssh_opts
    assert_script_run('curl ' . data_url('publiccloud/ssh_config') . ' -o ~/.ssh/config');
    assert_script_run "ssh-keyscan " . $instance->public_ip . " >> ~/.ssh/known_hosts";
    $instance->ssh_opts("");

    # Create the ssh alias
    assert_script_run('echo -en "Host sut\n  Hostname ' . $instance->public_ip . '\n" >> ~/.ssh/config');

    # Copy the SSH settings also for normal user
    assert_script_run("mkdir /home/" . $testapi::username . "/.ssh");
    assert_script_run("chmod -R 700 /home/" . $testapi::username . "/.ssh/");
    assert_script_run("cp ~/.ssh/* /home/" . $testapi::username . "/.ssh/");
    assert_script_run("chown -R " . $testapi::username . " /home/" . $testapi::username . "/.ssh/");

    # configure ssh server, allow root and password login
    $instance->run_ssh_command(cmd => 'hostname');
    $instance->run_ssh_command(cmd => 'sudo sed -i "s/PasswordAuthentication/#PasswordAuthentication/" /etc/ssh/sshd_config; echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config');
    $instance->run_ssh_command(cmd => 'sudo sed -i "s/ChallengeResponseAuthentication/#ChallengeResponseAuthentication/" /etc/ssh/sshd_config; echo "ChallengeResponseAuthentication no" | sudo tee -a /etc/ssh/sshd_config');
    $instance->run_ssh_command(cmd => 'echo -e "' . $testapi::password . '\n' . $testapi::password . '" | sudo passwd root');
    $instance->run_ssh_command(cmd => 'sudo sed -i "s/PermitRootLogin no/PermitRootLogin yes/g" /etc/ssh/sshd_config');
    $instance->run_ssh_command(cmd => "sudo mkdir -p /root/.ssh");
    $instance->run_ssh_command(cmd => "sudo chmod -R 700 /root/.ssh");
    $instance->run_ssh_command(cmd => 'sudo cp /home/' . $instance->username() . '/.ssh/authorized_keys /root/.ssh/');
    $instance->run_ssh_command(cmd => 'sudo chmod 644 /root/.ssh/authorized_keys');
    $instance->run_ssh_command(cmd => 'sudo chown root /root/.ssh/authorized_keys');
    $instance->run_ssh_command(cmd => 'sudo systemctl reload sshd');

    # Create normal user on remote instance and make it accessible by key
    $instance->run_ssh_command(cmd => "sudo useradd " . $testapi::username);
    $instance->run_ssh_command(cmd => "sudo mkdir /home/" . $testapi::username);
    $instance->run_ssh_command(cmd => "sudo chown -R " . $testapi::username . " /home/" . $testapi::username . "/");
    $instance->run_ssh_command(cmd => 'echo -e "' . $testapi::password . '\n' . $testapi::password . '" | sudo passwd ' . $testapi::username);
    $instance->run_ssh_command(cmd => "sudo mkdir /home/" . $testapi::username . "/.ssh");
    $instance->run_ssh_command(cmd => "sudo chmod -R 700 /home/" . $testapi::username . "/.ssh");
    $instance->run_ssh_command(cmd => 'sudo cp /home/' . $instance->username() . '/.ssh/authorized_keys /home/' . $testapi::username . '/.ssh/');
    $instance->run_ssh_command(cmd => "sudo chmod 644 /home/" . $testapi::username . "/.ssh/authorized_keys");
    $instance->run_ssh_command(cmd => "sudo chown -R " . $testapi::username . " /home/" . $testapi::username . "/.ssh/");

    # Print ssh_serial_ready to serial console when interactive ssh session is initiated
    $instance->run_ssh_command(cmd => "echo \"if tty -s; then echo ssh_serial_ready >> /dev/sshserial; fi\" > .bashrc");
    $instance->run_ssh_command(cmd => "sudo chmod 777 .bashrc");
    $instance->run_ssh_command(cmd => "sudo cp .bashrc /root/");
    $instance->run_ssh_command(cmd => "sudo cp .bashrc /home/" . $testapi::username . "/");
}

sub test_flags {
    return {
        fatal                    => 1,
        milestone                => 0,
        publiccloud_multi_module => 1
    };
}

1;
