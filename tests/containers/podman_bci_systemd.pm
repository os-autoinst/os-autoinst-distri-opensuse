# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman
# Summary: Test podman with systemd
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $podman = $self->containers_factory('podman');
    $self->{podman} = $podman;

    record_info("Podman version", script_output("podman version"));

    record_info('Test', 'Launch a container with systemd');
    assert_script_run("podman run -d -p 80:80 --health-cmd='curl http://localhost' --name nginx registry.suse.com/bci/bci-init:latest");

    record_info('Test', 'Install nginx');
    # Remove additional repos from the host, nginx package will be installed from BCI repo only.
    assert_script_run("podman exec nginx rm /usr/lib/zypp/plugins/services/container-suseconnect-zypp");
    assert_script_run("podman exec nginx zypper -n in nginx");
    assert_script_run("podman exec nginx bash -c 'echo testpage123-content > /srv/www/htdocs/index.html'");

    record_info('Test', 'Start nginx');
    assert_script_run("podman exec nginx systemctl start nginx");

    record_info('Test', 'Wait for nginx to be healthy');
    script_retry("podman exec nginx systemctl show -P ActiveState -P SubState nginx | grep -Pz 'active\\nrunning'", retry => 10, delay => 15);

    record_info('Test', 'Curl localhost from container');
    validate_script_output("podman exec nginx curl -sfL http://localhost", qr/testpage123-content/);

    record_info('Test', 'Curl localhost from host');
    validate_script_output("curl http://localhost", qr/testpage123-content/);
}

sub cleanup {
    my ($self) = @_;
    script_run("podman stop nginx");
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
