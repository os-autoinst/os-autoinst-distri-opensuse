# SUSE's openQA tests
#
# Copyright SUSE LL# SPDX-License-Identifier: FSFAP

# Package: podman docker helm
# Summary: Login to SUSE Container Registry using container runtime (docker/podman),
#          and (optionally) Helm registry login if HELM_CHART is defined.
# - login to registry.suse.com using docker|podman login
# - if HELM_CHART is defined, also run: helm registry login
# Maintainer: qe-c <qe-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $registry = get_required_var('SCC_REGISTRY');
    my $username = get_required_var('SCC_PROXY_USERNAME');
    my $password = get_required_var('SCC_PROXY_PASSWORD');

    select_serial_terminal;

    my $runtime = get_required_var('CONTAINER_RUNTIMES');

    # Container runtime login
    assert_script_run(
        qq(echo "$password" | $runtime login -u "$username" --password-stdin $registry)
    ) if script_run("command -v $runtime") == 0;

    # If HELM_CHART is set, also log in Helm's OCI registry (covers oci:// charts)
    if (get_var('HELM_CHART')) {
        assert_script_run(
            qq(echo "$password" | helm registry login -u "$username" --password-stdin $registry)
        ) if script_run("command -v helm") == 0;
        assert_script_run(
            qq(kubectl create secret docker-registry suse-registry --docker-server=$registry --docker-username=$username --docker-password=$password)
        ) if script_run("command -v kubectl") == 0;
    }
}

1;
