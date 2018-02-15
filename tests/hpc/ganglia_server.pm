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
use base "x11regressiontest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self        = shift;
    my $slave_ip    = get_required_var('HPC_SLAVE_IP');
    my ($server_ip) = get_required_var('HPC_HOST_IP') =~ /(.*)\/.*/;
    barrier_create("GANGLIA_INSTALLED",      2);
    barrier_create("GANGLIA_SERVER_DONE",    2);
    barrier_create("GANGLIA_CLIENT_DONE",    2);
    barrier_create("GANGLIA_GMETAD_STARTED", 2);
    barrier_create("GANGLIA_GMOND_STARTED",  2);

    assert_script_run('hostnamectl set-hostname ganglia-server');
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
    assert_script_run('a2enmod php7');
    systemctl('start apache2');

    # switch to gui
    select_console('x11');

    # start browser and access ganglia web ui
    x11_start_program("firefox http://$server_ip/ganglia", valid => 0);
    $self->firefox_check_default;
    assert_screen('ganglia-web');
    assert_and_click('ganglia-node-dropdown');
    assert_and_click('ganglia-select-server-node');
    assert_screen('ganglia-node-report', 60);

    # tell client that server is done
    barrier_wait('GANGLIA_SERVER_DONE');
}
1;
