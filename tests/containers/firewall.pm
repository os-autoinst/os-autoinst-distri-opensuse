# SUSE's openQA tests
#
# Copyright 2021-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: firewall
# Summary: Test podman or docker with enabled firewall
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'script_retry';
use containers::utils qw(registry_url);
use containers::common 'check_containers_connectivity';
use Utils::Systemd 'systemctl';

my $runtime;
my $stop_firewall = 0;

sub run {
    my ($self, $args) = @_;
    $runtime = $args->{runtime};
    select_serial_terminal;

    my $engine = $self->containers_factory($runtime);
    my $container_name = 'sut_container';

    # Test firewall only on systems where it's installed
    die('Firewall is not present.') unless ($self->firewall() == 'firewalld' && script_run('which ' . $self->firewall()) == 0);

    # Start firewall if it was not running before
    if (script_run('systemctl is-active ' . $self->firewall()) != 0) {
        systemctl('start ' . $self->firewall());
        systemctl('restart docker') if ($runtime eq "docker");
        $stop_firewall = 1;
    }

    # Run netcat in container and check that we can reach it
    assert_script_run "$runtime pull " . registry_url('alpine');
    assert_script_run "$runtime run -d --name $container_name -p 1234:1234 " . registry_url('alpine') . " nc -l -p 1234";
    assert_script_run "echo Hola Mundo >/dev/tcp/127.0.0.1/1234";
    assert_script_run "$runtime logs $container_name | grep Hola";

    assert_script_run "$runtime stop $container_name ";
    assert_script_run "$runtime rm -vf $container_name ";

    # Test container connectivity
    check_containers_connectivity($engine);

    # Stop the firewall if it was started by this test module
    if ($stop_firewall == 1) {
        systemctl('stop ' . $self->firewall());
        systemctl('restart docker') if ($runtime eq "docker");
    }

    $engine->cleanup_system_host();
}

sub post_fail_hook {
    my ($self) = @_;

    # Stop the firewall if it was started by this test module
    if ($stop_firewall == 1) {
        systemctl('stop ' . $self->firewall());
        systemctl('restart docker', ignore_failure => 1) if ($runtime eq "docker");
    }

    $self->SUPER::post_fail_hook;
}

1;
