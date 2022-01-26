# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for cups service tests
#
# Maintainer: qa-c team <qa-c@suse.de>

package services::docker;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;
use containers::docker;
use containers::utils qw(basic_container_tests registry_url);
use containers::container_images 'build_and_run_image';

my $service_type = 'Systemd';

# check service is running and enabled
sub check_service {
    common_service_action 'docker', $service_type, 'is-enabled';
    common_service_action 'docker', $service_type, 'is-active';
}

# check docker service before and after migration
# stage is 'before' or 'after' system migration.
sub full_docker_check {
    my (%hash) = @_;
    my ($stage, $type) = ($hash{stage}, $hash{service_type});
    $service_type = $type;
    my $engine = containers::docker->new();
    $engine->init() if ($stage eq 'before');

    check_service();

    # Test the connectivity of Docker containers
    $engine->check_containers_connectivity();

    # Run basic runtime tests
    basic_container_tests(runtime => $engine->runtime);

    # Clean container
    $engine->cleanup_system_host();

    check_service();
}

1;
