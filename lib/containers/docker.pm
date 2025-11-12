# SUSE's openQA tests
#
# Copyright 2020-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for docker specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::docker;
use strict;
use warnings;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use containers::common qw(install_docker_when_needed);
use utils qw(systemctl file_content_replace);
has runtime => 'docker';

sub init {
    install_docker_when_needed();
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;
    return if (script_run("grep -q insecure-registries /etc/docker/daemon.json") == 0);
    my $registry = registry_url();
    # The debug output is messing with terminal in migration tests
    my $debug = (get_var('UPGRADE')) ? 'false' : 'true';
    # Allow our internal 'insecure' registry only if REGISTRY variable is set
    assert_script_run "test -f /etc/docker/daemon.json || echo '{\"log-level\": \"info\"}' > /etc/docker/daemon.json";
    assert_script_run "sed -i 's%^{%&\"debug\":$debug,\"insecure-registries\":[\"$registry\"],%' /etc/docker/daemon.json";
    record_info('daemon.json', script_output("cat /etc/docker/daemon.json"));
    systemctl('restart docker');
}

sub get_storage_driver {
    my $storage = script_output("docker info -f '{{.Driver}}'");
    record_info 'Storage', "Detected storage driver=$storage";

    return $storage;
}

1;
