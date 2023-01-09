# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento deployment test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'script_retry';
use qesapdeployment 'qesap_upload_logs';
use trento;


sub run {
    my ($self) = @_;
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    select_serial_terminal;

    k8s_test();

    # test if the web page is reachable on http
    my $machine_ip = get_trento_ip();
    my $trento_url = "http://$machine_ip/";
    script_run('curl --version');
    assert_script_run('curl -k  ' . $trento_url);
    # HEAD request
    my $trento_http_code = script_output('curl -I --silent --output /dev/null --write-out "%{http_code}" ' . $trento_url);
    # HEAD request and follow redirection
    my $curl_cmd_test = 'test $(' .
      'curl -I -L --silent --output /dev/null --write-out "%{http_code}" ' . $trento_url .
      ') -eq 200 ';
    script_retry($curl_cmd_test, retry => 5, delay => 60);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support();
        trento_collect_scenarios('test_trento_deploy_fail');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
