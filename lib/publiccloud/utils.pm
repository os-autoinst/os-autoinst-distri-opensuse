# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Public cloud utilities
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

package publiccloud::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use version_utils;

our @EXPORT = qw(select_host_console is_publiccloud is_byos is_ondemand is_ec2 is_azure is_gce);

# Select console on the test host, regardless of the TUNNELED variable.
sub select_host_console {
    my (@args) = @_;
    if (check_var('TUNNELED', '1')) {
        select_console('tunnel-console', @args);
    } else {
        select_console('root-console', @args);
    }
    send_key "ctrl-c";
    send_key "ret";
}

sub is_publiccloud() {
    return (get_var('PUBLIC_CLOUD') == 1);
}

# Check if we are a BYOS test run
sub is_byos() {
    return is_publiccloud && get_var('FLAVOR') =~ 'BYOS';
}

# Check if we are a OnDemand test run
sub is_ondemand() {
    # By convention OnDemand images are not marked explicitly.
    # Check all the other flavors, and if they don't match, it must be on_demand.
    return is_publiccloud && (!is_byos());    # When introducing new flavors, add checks here accordingly.
}

# Check if we are on an AWS test run
sub is_ec2() {
    return is_publiccloud && check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
}

# Check if we are on an Azure test run
sub is_azure() {
    return is_publiccloud && check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
}

# Check if we are on an GCP test run
sub is_gce() {
    return is_publiccloud && check_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
}

1;
