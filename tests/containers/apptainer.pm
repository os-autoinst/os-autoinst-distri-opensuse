# SUSE's openQA tests
#
# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test apptainer container functionality
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils qw(zypper_call);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $image = 'registry.opensuse.org/opensuse/leap:latest';
    record_info('Installation', 'apptainer');
    zypper_call('install apptainer');
    record_info('Version', script_output('apptainer --version'));
    assert_script_run('export APPTAINER_TMPDIR=/var/tmp');
    assert_script_run('apptainer cache list');
    record_info('Smoke run', 'Pull image');
    validate_script_output(qq{apptainer run --containall --no-https docker://$image echo "hello"},
        sub { /hello/ }, timeout => 300);

    record_info('Run Tumbleweed container', "Create container from $image");
    validate_script_output(qq{apptainer run --containall docker://$image cat /etc/os-release}, sub { /PRETTY_NAME="openSUSE Leap/ });

    record_info('Build', "Build sandbox from $image");
    assert_script_run(qq{apptainer build --sandbox my_os/ docker://$image});
    assert_script_run('ls -la my_os');
    assert_script_run('apptainer exec --writable my_os touch /foo');
    validate_script_output('apptainer exec my_os/ ls -l /foo', sub { /foo/ });

    record_info('Build with def file', 'Build from definition file');
    assert_script_run "curl " . data_url('containers/apptainer_container.def') . " -o ./apptainer_container.def";
    assert_script_run('apptainer build container.sif apptainer_container.def', timeout => 300);
    assert_script_run('apptainer cache list');
    assert_script_run('apptainer instance list');
    assert_script_run('apptainer instance start container.sif mycontainer');
    validate_script_output('apptainer instance list', sub { /mycontainer.*container.sif/ });
    script_run('apptainer shell instance://mycontainer', timeout => 0, quiet => 1);
    validate_script_output('cat /etc/os-release && echo testdone', sub { /testdone/ }, quiet => 1);
    script_run('exit', timeout => 0, quiet => 1);
    assert_script_run('apptainer instance stop mycontainer');
}

sub post_run_hook {
    my ($self) = @_;
    assert_script_run('rm -rf my_os apptainer_container.def container.sif',
        fail_message => "failed to remove test data. Check current folder: \n" . script_output('ls -l'));
    zypper_call('remove apptainer');
}

1;
