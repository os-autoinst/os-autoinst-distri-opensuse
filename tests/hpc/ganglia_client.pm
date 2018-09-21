# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ganglia Test - client
#   Acts as client node, which publishes data to the server via gmetric command
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/323979

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use serial_terminal 'select_virtio_console';

sub run {
    my $self = shift;

    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");
    # Get ganglia-server hostname
    my $server_hostname = get_required_var("GANGLIA_SERVER_HOSTNAME");

    zypper_call 'in ganglia-gmond';

    # wait for gmetad to be started
    barrier_wait('GANGLIA_GMETAD_STARTED');
    systemctl "start gmond";
    barrier_wait('GANGLIA_GMOND_STARTED');

    # wait for server
    barrier_wait('GANGLIA_INSTALLED');

    # arbitrary number of retries
    my $max_retries = 7;
    for (1 .. $max_retries) {
        eval {
            # Wait for ganglia cluster setup
            sleep 5;
            # Check if gmond has connected to gmetad
            validate_script_output "gstat -a", sub { m/.*Hosts: ${nodes}.*/ };
        };
        last unless ($@);
        record_info 'waiting for nodes', 'Not all nodes connected yet. Retrying...';
    }
    die "Not all nodes were connected after $max_retries retries." if $@;

    # Check if an arbitrary value could be sent via gmetric command
    my $testMetric = "openQA";
    type_string "gmetric -n \"$testMetric\" -v \"openQA\" -t string | tee /dev/ttyS0";
    my $gmetric_max_retries = 3;
    for (1 .. $gmetric_max_retries) {
        eval {
            # Wait for gmetric update
            sleep 5;
            # Check if gmetric is available
            assert_script_run "echo \"\\n\" | nc ${server_hostname} 8649 | grep $testMetric";
        };
        last unless ($@);
        record_info 'waiting for gmetric', 'Gmetric not available yet. Retrying...';
    }
    die "Gmetric test failed after $gmetric_max_retries retries." if $@;

    barrier_wait('GANGLIA_CLIENT_DONE');
    barrier_wait('GANGLIA_SERVER_DONE');
}

sub post_fail_hook {
    my ($self) = @_;
    select_virtio_console(force => 1);
    $self->upload_service_log('gmond');
}

1;
