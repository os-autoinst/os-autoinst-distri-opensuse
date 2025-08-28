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
use containers::k8s qw(install_kubectl install_helm);

sub run {
    my $registry = get_required_var('SCC_REGISTRY');
    my $username = get_required_var('SCC_PROXY_USERNAME');
    my $password = get_required_var('SCC_PROXY_PASSWORD');

    select_serial_terminal;

    install_helm();

    assert_script_run(
        qq(echo "$password" | helm registry login -u "$username" --password-stdin $registry)
    );
    assert_script_run(
        qq(kubectl create secret docker-registry suse-registry --docker-server=$registry --docker-username=$username --docker-password=$password)
    );
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
