# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for podman specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::podman;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use containers::common qw(install_podman_when_needed);
use utils qw(file_content_replace);
use version_utils qw(get_os_release);
has runtime => "podman";

sub init {
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_podman_when_needed($host_distri);
    configure_insecure_registries();
}

sub configure_insecure_registries {
    my ($self) = shift;

    assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
    assert_script_run "chmod 644 /etc/containers/registries.conf";
    # Add custom registry only if set by the REGISTRY variable
    assert_script_run('echo -e \'[[registry]]\nlocation = "' . registry_url() . '"\ninsecure = true\' >> /etc/containers/registries.conf') if get_var('REGISTRY');
}

1;
