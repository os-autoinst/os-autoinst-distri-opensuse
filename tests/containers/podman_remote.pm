# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman-remote functionality
# Maintainer: qe-c <qe-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils qw(script_retry systemctl);
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);

sub run {
    my ($self, $args) = @_;
    my $image = 'registry.opensuse.org/opensuse/tumbleweed:latest';

    select_serial_terminal();
    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;

    # Prepare ssh from root to the normal user
    systemctl 'enable --now sshd';
    assert_script_run('ssh-keygen -t ecdsa -N "" -C "podman-remote" -f ~/.ssh/podman-remote_ecdsa');
    assert_script_run "install -o $testapi::username -g users -m 0700 -d /home/$testapi::username/.ssh";
    assert_script_run "cat ~/.ssh/podman-remote_ecdsa.pub | tee -a /home/$testapi::username/.ssh/authorized_keys";
    assert_script_run "chown $testapi::username:users /home/$testapi::username/.ssh/authorized_keys";
    assert_script_run "chmod 0644 /home/$testapi::username/.ssh/authorized_keys";

    # Pull and run a container named test-root
    script_retry "podman pull $image", timeout => 300, retry => 3, delay => 120;
    assert_script_run "podman run -d --rm --name test-root $image sleep infinity";

    # Run the podman daemon as normal user
    select_user_serial_terminal();
    systemctl '--user enable --now podman.socket';

    # Pull and run a container named test-user
    script_retry "podman pull $image", timeout => 300, retry => 3, delay => 120;
    assert_script_run "podman run -d --rm --name test-user $image sleep infinity";

    # Add the podman-remote connection to the user's podman via SSH
    select_serial_terminal();
    my $uid = script_output "id -u $testapi::username";
    my $connection = "ssh://$testapi::username@127.0.0.1:22/run/user/$uid/podman/podman.sock";
    assert_script_run "podman --remote system connection add test --identity ~/.ssh/podman-remote_ecdsa $connection";
    validate_script_output 'podman --remote system connection list', sub { m@$connection@; };

    # Validate podman-remote sees containers launched by the user (as it is connected to user's podman daemon) and not containers launched by root
    validate_script_output 'podman --remote container ls', sub { m/test-user/; }, fail_message => "user container not listed";
    validate_script_output 'podman --remote container ls', sub { !m/test-root/; }, fail_message => "root container present in user session";

    # Validate podman sees containers launched by root (as it is executed under root) and not containers launched by user
    validate_script_output 'podman container ls', sub { m/test-root/; }, fail_message => "root containers are not present";
    validate_script_output 'podman container ls', sub { !m/test-user/; }, fail_message => "user containers are visible to root";
}

sub cleanup {
    my ($self) = @_;
    select_serial_terminal();
    $self->{podman}->cleanup_system_host();
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

1;
