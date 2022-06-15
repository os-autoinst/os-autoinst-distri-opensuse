# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for docker specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::docker;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url get_docker_version check_runtime_version);
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
    # Allow our internal 'insecure' registry only if REGISTRY variable is set
    my $str = '{ \"debug\": ' . $debug;
    $str .= get_var('REGISTRY') ? ', \"insecure-registries\" : [\"' . $registry . '\"] }' : '}';
    my $config = script_output("echo $str | tee /etc/docker/daemon.json");
    record_info('daemon.json', $config);
    systemctl('restart docker');
}

1;
