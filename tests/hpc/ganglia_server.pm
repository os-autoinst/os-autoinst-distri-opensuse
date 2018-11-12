# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ganglia Test - server
#   Acts as server which gets data from the client and is running the webinterface
#   to show the metrics for all connected hosts
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/323979

use base "hpcbase";
use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");
    # Get hostname
    my $hostname = get_required_var("HOSTNAME");

    zypper_call('in ganglia-gmetad ganglia-gmond ganglia-gmetad-skip-bcheck');
    systemctl 'start gmetad';
    barrier_wait('GANGLIA_GMETAD_STARTED');
    systemctl 'start gmond';
    barrier_wait('GANGLIA_GMOND_STARTED');

    # wait for client
    barrier_wait('GANGLIA_INSTALLED');
    barrier_wait('GANGLIA_CLIENT_DONE');

    #install web frontend and start apache
    zypper_call('in ganglia-web');
    # SLE15 has installed by default php7, SLE12 has php5
    my $php_mod = is_sle('15+') ? 'php7' : 'php5';
    script_run('a2enmod ' . $php_mod);
    systemctl('start apache2');
    my $page_url = "http://ganglia-server/ganglia/?r=hour&cs=&ce=&c=unspecified&h=";
    $page_url .= "ganglia-server.openqa.test&tab=m&vn=&hide-hf=false";
    my $image_url = "http://ganglia-server/ganglia/graph.php?r=hour&z=xlarge&h=";
    $image_url .= "ganglia-server.openqa.test&m=load_one&s=by+name&mc=2&g=cpu_report&c=unspecified";

    assert_script_run("curl -s \"$page_url\" > test.html");
    assert_script_run('grep -q "Host Overview" test.html');
    assert_script_run('grep -q "Expand All Metric Groups" test.html');
    assert_script_run('grep -q "Ganglia Web Frontend version" test.html');

    assert_script_run("curl -s \"$image_url\" > test2.png");
    assert_script_run('file test2.png | grep -q "PNG image data"');

    # tell client that server is done
    barrier_wait('GANGLIA_SERVER_DONE');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('apache2');
    $self->upload_service_log('gmond');
    $self->upload_service_log('gmetad');
}

1;
