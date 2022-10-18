# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ganglia Test - server
#   Acts as server which gets data from the client and is running the webinterface
#   to show the metrics for all connected hosts
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/323979

use Mojo::Base qw(hpcbase x11test), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils;
use version_utils 'is_sle';

sub run ($self) {
    # Get number of nodes
    my $nodes = get_required_var("CLUSTER_NODES");
    # Get hostname
    my $hostname = get_required_var("HOSTNAME");

    zypper_call('in ganglia-gmetad ganglia-gmond ganglia-gmetad-skip-bcheck');
    systemctl 'start gmetad';
    barrier_wait('GANGLIA_GMETAD_STARTED');
    systemctl 'start gmond';
    barrier_wait('GANGLIA_GMOND_STARTED');

    # Wait for client.
    barrier_wait('GANGLIA_INSTALLED');
    barrier_wait('GANGLIA_CLIENT_DONE');

    # Install web frontend and start apache2.
    zypper_call('in ganglia-web');

    # Check which version of php was installed during the previous step.
    my $php_ver = '';
    if (!zypper_call('se -i apache2-mod_php7', exitcode => [0, 104])) {
        $php_ver = '7';
    }
    elsif (!zypper_call('se -i apache2-mod_php5', exitcode => [0, 104])) {
        $php_ver = '5';
    }
    else {
        record_info("Depedency issue", "Is apache-mod_php installed?");
        die;
    }
    script_run("a2enmod php$php_ver");

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

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    select_serial_terminal;
    $self->upload_service_log('apache2');
    $self->upload_service_log('gmond');
    $self->upload_service_log('gmetad');
}

1;
