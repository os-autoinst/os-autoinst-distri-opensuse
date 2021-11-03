# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for docker specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::docker;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use utils qw(systemctl file_content_replace);
has runtime => 'docker';

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();
    # Allow our internal 'insecure' registry
    assert_script_run(
        'echo "{ \"debug\": true, \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\", \"' . $registry . '\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');
    record_info "setup $self->runtime", "deamon.json ready";
}

1;
