# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman, docker
# Summary: Test RT workload in a container
# Maintainer: qa-c@suse.de

use Mojo::Base qw(containers::basetest);
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry);

# run a RT process, change priority and scheduling policy FIFO and later change to RoundRobin
sub test_schedule {
    my ($is_rt, $runtime, $container) = @_;

    assert_script_run("$runtime exec $container chrt -m");
    validate_script_output("$runtime exec $container cat /sys/kernel/realtime", qr/^1$/);
    assert_script_run("$runtime exec $container test -f /proc/sys/kernel/sched_rt_period_us");
    assert_script_run("$runtime exec $container test -f /proc/sys/kernel/sched_rt_runtime_us");

    # chrt does not return non zero code when fails to spawn a RT process, just error message
    # existance of PID ensures that the command ran successfully
    assert_script_run("$runtime exec $container /bin/bash -c 'chrt -f 96 sleep 100&'");
    my $pid = script_output("$runtime exec $container pidof sleep", proceed_on_failure => 1);

    if ($is_rt) {
        if ($pid) {
            validate_script_output("$runtime exec $container chrt -p $pid", qr/SCHED_FIFO/);

            # change to round robin
            assert_script_run("$runtime exec $container chrt -r -p 69 $pid");
            validate_script_output("$runtime exec $container chrt -p $pid", qr/SCHED_RR/);
        } else {
            die 'Container with capability SYS_NICE was not able to run RT workload';
        }
    }

    if ($pid && !$is_rt) {
        die 'Container without capability SYS_NICE was able to run RT workload';
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    my $runtime = $args->{runtime};
    my $container = 'rt-test';
    my $image = 'registry.opensuse.org/opensuse/tumbleweed:latest';

    $self->{runtime} = $self->containers_factory($runtime);
    script_retry("$runtime pull $image", timeout => 300, delay => 120, retry => 3);

    # spawn a container without capabilities
    # process prioties cannot be changed
    assert_script_run("$runtime run --rm --name $container -dt $image");
    test_schedule(0, $runtime, $container);
    assert_script_run("$runtime stop $container");

    # spawn a container with SYS_NICE capability
    assert_script_run("$runtime run --rm --name $container -dt --cap-add=CAP_SYS_NICE $image");
    test_schedule(1, $runtime, $container);
}

sub _cleanup {
    my ($self) = @_;
    $self->{runtime}->cleanup_system_host();
    delete $self->{runtime};
}

sub post_run_hook {
    my ($self) = @_;
    $self->_cleanup();
}

sub post_fail_hook {
    my ($self) = @_;
    $self->_cleanup();
}

1;
