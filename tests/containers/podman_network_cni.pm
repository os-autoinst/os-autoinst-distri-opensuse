# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman network
# Summary: Test podman network
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(package_version_cmp);
use containers::utils qw(registry_url container_ip);
use containers::utils qw(get_podman_version);


sub run() {

    my ($self, $args) = @_;
    select_serial_terminal;
    my $podman = $self->containers_factory('podman');


    my $podman_version = get_podman_version();
    my $old_podman = (package_version_cmp($podman_version, '3.1.0') >= 0) ? 0 : 1;

    record_info('Create', 'Create new networks named newnet1 and newnet2');
    assert_script_run('podman network create newnet1');
    assert_script_run('podman network create newnet2');

    record_info('List', script_output('podman network ls'));
    validate_script_output('podman network ls', sub { m/newnet/g });
    unless ($old_podman) {
        assert_script_run("podman network exists newnet1");
        assert_script_run("podman network exists newnet2");
    }

    record_info('Create', 'Create two more networks named newnet3 and newnet4');
    assert_script_run('podman network create newnet3');
    assert_script_run('podman network create newnet4');

    record_info('Delete', 'Delete newnet3 and list the networks to see if it is deleted');
    assert_script_run('podman network rm newnet3');
    validate_script_output('podman network ls', sub { !m/newnet3/ });
    unless ($old_podman) {
        script_run('podman network exists newnet3') or die('newnet3 has not been deleted!');
    }

    unless ($old_podman) {
        record_info('Inspect', script_output('podman inspect newnet1'));
        assert_script_run('podman network inspect newnet1 --format "{{range .Subnets}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{end}}"');
    }

    record_info('Cleanup', 'Remove all unused networks');
    unless ($old_podman) {
        assert_script_run('podman network prune -f');
        validate_script_output('podman network ls', sub { !m/newnet/ });
    }

    $podman->cleanup_system_host();

}

1;
