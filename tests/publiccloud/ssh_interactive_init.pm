# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openssh
# Summary: This tests will deploy the public cloud instance and prepare the ssh
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::utils "select_host_console";
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;

    # If someone schedules a publiccloud run with a custom SCHEDULE this causes
    # the test to break, because we need to pass $args, so dying earlier and with clear message about root cause
    die('Note: Running publiccloud with a custom SCHEDULE is not supported') if (!defined $args);

    select_host_console();    # select console on the host, not the PC instance

    # Create public cloud instance
    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance(check_connectivity => 1);
    $instance->wait_for_guestregister();
    $args->{my_provider} = $provider;
    $args->{my_instance} = $instance;

    # configure ssh client, fetch the instance ssh public key, do not use default $instance->ssh_opts
    my $ssh_config_url = data_url('publiccloud/ssh_config');
    assert_script_run("curl $ssh_config_url -o ~/.ssh/config");
    assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));
    $instance->ssh_opts("");

    # Create the ssh alias
    assert_script_run(sprintf(q(echo -e 'Host sut\n  Hostname %s' >> ~/.ssh/config), $instance->public_ip));

    # Copy SSH settings also for normal user
    assert_script_run("install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    assert_script_run("install -o $testapi::username -g users -m 0600 ~/.ssh/* /home/$testapi::username/.ssh/");

    # Skip setting root password for img_proof, because it expects the root password to NOT be set
    unless (get_var('PUBLIC_CLOUD_QAM') && get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
        $instance->run_ssh_command(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd root));
    }

    # Permit root passwordless login over SSH
    $instance->run_ssh_command('sudo sed -i "s/PermitRootLogin no/PermitRootLogin prohibit-password/g" /etc/ssh/sshd_config');
    $instance->run_ssh_command('sudo systemctl reload sshd');

    # Copy SSH settings for remote root
    $instance->run_ssh_command('sudo install -o root -g root -m 0700 -dD /root/.ssh');
    $instance->run_ssh_command(sprintf("sudo install -o root -g root -m 0644 /home/%s/.ssh/authorized_keys /root/.ssh/", $instance->{username}));

    # Create remote user and set him a password
    $instance->run_ssh_command("sudo useradd -m $testapi::username");
    $instance->run_ssh_command(qq(echo -e "$testapi::password\\n$testapi::password" | sudo passwd $testapi::username));

    # Copy SSH settings for remote user
    $instance->run_ssh_command("sudo install -o $testapi::username -g users -m 0700 -dD /home/$testapi::username/.ssh");
    $instance->run_ssh_command("sudo install -o $testapi::username -g users -m 0644 ~/.ssh/authorized_keys /home/$testapi::username/.ssh/");

    # Create log file for ssh tunnel
    my $ssh_sut = '/var/tmp/ssh_sut.log';
    assert_script_run "touch $ssh_sut; chmod 777 $ssh_sut";

}

sub test_flags {
    return {
        fatal                    => 1,
        milestone                => 0,
        publiccloud_multi_module => 1
    };
}

1;
