# SUSE's openQA tests
#
# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman network
# Summary: Test podman network
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils qw(script_retry);
use serial_terminal 'select_serial_terminal';
use version_utils qw(package_version_cmp);
use containers::utils qw(container_ip);
use containers::utils qw(get_podman_version);


sub run() {

    my ($self, $args) = @_;
    select_serial_terminal;

    my $podman = $self->containers_factory('podman');
    my $podman_version = get_podman_version();
    my $supports_network = (package_version_cmp($podman_version, '3.1.0') >= 0) ? 0 : 1;

    record_info('Create', 'Create new networks named newnet1 and newnet2');
    assert_script_run('podman network create newnet1');
    assert_script_run('podman network create newnet2');

    record_info('List', script_output('podman network ls'));
    validate_script_output('podman network ls', sub { m/newnet/g });
    unless ($supports_network) {
        assert_script_run("podman network exists newnet1");
        assert_script_run("podman network exists newnet2");
    }

    record_info('Create', 'Create two more networks named newnet3 and newnet4');
    assert_script_run('podman network create newnet3');
    assert_script_run('podman network create newnet4');

    record_info('Delete', 'Delete newnet3 and list the networks to see if it is deleted');
    assert_script_run('podman network rm newnet3');
    validate_script_output('podman network ls', sub { !m/newnet3/ });
    unless ($supports_network) {
        script_run('podman network exists newnet3') or die('newnet3 has not been deleted!');
    }

    unless ($supports_network) {
        record_info('Inspect', script_output('podman inspect newnet1'));
        assert_script_run('podman network inspect newnet1 --format "{{range .Subnets}}Subnet: {{.Subnet}} Gateway: {{.Gateway}}{{end}}"');
    }

    #connect, disconnect & reload
    unless ($supports_network) {
        my $image = "registry.opensuse.org/opensuse/busybox";
        record_info('Prepare', 'Prepare three containers');
        script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);

        assert_script_run("podman run -id --rm --name container1 -p 1234:1234 $image");
        assert_script_run("podman run -id --rm --name container2 -p 1235:1235 $image");
        assert_script_run("podman run -id --rm --name container3 -p 1236:1236 $image");

        my $container_id = script_output("podman inspect -f '{{.Id}}' container3");

        record_info('Connect', 'Connect the containers to the networks');
        assert_script_run('podman network connect newnet1 container1');
        assert_script_run('podman network connect newnet2 container2');
        assert_script_run('podman network connect newnet2 container3');

        record_info('Inspect', 'Inspect that the containers belong to their respective networks');
        validate_script_output('podman inspect --format="{{.NetworkSettings.Networks}}" container1', sub { m/newnet1/ });
        validate_script_output('podman inspect --format="{{.NetworkSettings.Networks}}" container2', sub { m/newnet2/ });
        validate_script_output('podman inspect --format="{{.NetworkSettings.Networks}}" container3', sub { m/newnet2/ });

        record_info('Disconnect', 'Disconnect the container from the network');
        assert_script_run('podman network disconnect newnet2 container2');
        validate_script_output('podman inspect --format="{{.NetworkSettings.Networks}}" container2', sub { !m/newnet2/ });

        record_info('Reload', 'Reload the container network configuration');
        validate_script_output('podman network reload container3', sub { m/$container_id/ });
    }

    record_info('Cleanup', 'Remove all unused networks');
    unless ($supports_network) {
        assert_script_run('podman network prune -f');
        validate_script_output('podman network ls', sub { !m/newnet4/ });
    }

    $podman->cleanup_system_host();

}

1;
