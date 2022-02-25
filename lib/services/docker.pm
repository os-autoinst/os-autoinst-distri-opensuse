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
use containers::utils 'runtime_smoke_tests';

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

    # Test the basic functionality
    runtime_smoke_tests(runtime => $engine);

    # Clean container (assert => 0 will skip script_output checks)
    $engine->cleanup_system_host(assert => 0);

    check_service();
}

1;
