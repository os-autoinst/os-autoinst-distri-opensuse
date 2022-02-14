# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for docker specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::docker;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url get_docker_version check_runtime_version container_ip container_route);
use containers::common qw(install_docker_when_needed);
use utils qw(systemctl file_content_replace);
use version_utils qw(get_os_release);
has runtime => 'docker';

sub init {
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();
    # The debug output is messing with terminal in migration tests
    my $debug = (get_var('UPGRADE')) ? 'false' : 'true';
    # Allow our internal 'insecure' registry
    assert_script_run(
'echo "{ \"debug\": ' . $debug . ', \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\", \"' . $registry . '\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');
    record_info "setup $self->runtime", "deamon.json ready";
}

sub check_containers_connectivity {
    record_info "connectivity", "Checking that containers can connect to the host, to each other and outside of the host";
    my $container_name = 'sut_container';

    # Run container in the background
    assert_script_run "docker run -id --rm --name $container_name -p 1234:1234 " . registry_url('alpine') . " sleep 30d";
    my $container_ip = container_ip($container_name, 'docker');

    # Connectivity to host check
    my $default_route = container_route($container_name, 'docker');
    assert_script_run "docker run --rm " . registry_url('alpine') . " ping -c3 " . $default_route;

    # Cross-container connectivity check
    assert_script_run "docker run --rm " . registry_url('alpine') . " ping -c3 " . $container_ip;

    # Outisde connectivity check
    assert_script_run "docker run --rm " . registry_url('alpine') . " wget google.com";

    # Kill the container running on background
    assert_script_run "docker kill $container_name ";
}

1;
