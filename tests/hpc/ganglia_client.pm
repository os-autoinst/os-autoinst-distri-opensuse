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

sub run {
    my $self = shift;
    my ($server_ip) = get_required_var('HPC_MASTER_IP') =~ /(.*)\/.*/;

    assert_script_run('hostnamectl set-hostname ganglia-client');
    zypper_call 'in ganglia-gmond';
    systemctl "start gmond";

    # wait for server
    barrier_wait('GANGLIA_INSTALLED');

    # Check if gmond has connected to gmetad
    validate_script_output "gstat -a", sub { m/.*Hosts: 2.*/ };

    # Check if an arbitrary value could be sent via gmetric command
    my $testMetric = "openQA";
    type_string "gmetric -n \"$testMetric\" -v \"openQA\" -t string | tee /dev/ttyS0";
    assert_script_run "echo \"\\n\" | nc $server_ip 8649 | grep $testMetric";

    barrier_wait('GANGLIA_CLIENT_DONE');
    barrier_wait('GANGLIA_SERVER_DONE');
}
1;
