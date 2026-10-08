# SUSE's openQA tests
#
# Copyright SUSE LL# SPDX-License-Identifier: FSFAP

# Package: helm
# Summary: Login to a registry using container runtime (docker/podman) via helm
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use utils;
use serial_terminal qw(select_serial_terminal);
use containers::helm;
use containers::k8s qw(install_kubectl install_helm);
use main_containers qw(is_suse_host);

sub run {
    select_serial_terminal;

    my $logins = get_required_var('HELM_LOGIN');

    for my $login (split(/,/, $logins)) {
        $login =~ s/^\s+|\s+$//g;    # trim whitespaces
        my ($registry, $username, $password) = split(':', $login);

        assert_script_run(
            qq(echo "$password" | helm registry login -u "$username" --password-stdin $registry)
        );
        assert_script_run(
            qq(kubectl create secret docker-registry suse-registry --docker-server=$registry --docker-username=$username --docker-password=$password)
        );
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
