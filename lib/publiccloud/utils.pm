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
use publiccloud::ssh_interactive;

our @EXPORT = qw(select_host_console is_publiccloud is_byos is_ondemand is_ec2 is_azure is_gce);

# Select console on the test host, if force is set, the interactive session will
# be destroyed. If called in TUNNELED environment, this function die.
#
# select_host_console(force => 1)
#
sub select_host_console {
    my (%args) = @_;
    $args{force} //= 0;
    my $tunneled = get_var('TUNNELED');

    if ($tunneled && check_var('_SSH_TUNNELS_INITIALIZED', 1)) {
        die("Called select_host_console but we are in TUNNELED mode") unless ($args{force});

        opensusebasetest::select_serial_terminal();
        ssh_interactive_leave();

        select_console('tunnel-console', await_console => 0);
        send_key 'ctrl-c';
        send_key 'ret';

        set_var('_SSH_TUNNELS_INITIALIZED', 0);
        opensusebasetest::clear_and_verify_console();
        save_screenshot;
    }
    set_var('TUNNELED', 0) if $tunneled;
    opensusebasetest::select_serial_terminal();
    set_var('TUNNELED', $tunneled) if $tunneled;
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
