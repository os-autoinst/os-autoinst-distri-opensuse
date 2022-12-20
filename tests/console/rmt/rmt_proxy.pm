# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-rmt rmt-server
# Summary: Add rmt configuration test and basic configuration via
#    rmt-wizard, test RMT basic function behind proxy.
# Preparation: Setup proxy server bind to a NTLM server, we can get
#   proxy_url,proxy_user,proxy_password through setting: PROXY_SERVER,
#   PROXY_USER,PROXY_PASSWORD
# On RMT test machine, set /etc/rmt.conf as:
#           proxy: http://PROXY_SERVER
#           proxy_user: PROXY_USER
#           proxy_password: PROXY_PASSWORD
#           proxy_auth: ntlm
# Maintainer: Lemon Li <leli@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use repo_tools;
use utils;

sub run {
    select_console 'root-console';
    record_info('RMT server setup', 'Start to setup a rmt server');
    rmt_wizard();
    # sync from SCC
    rmt_sync;

    # Set RMT behind a proxy (with NTLM Auth), and ensure RMT basic function works.
    record_info('Set proxy', 'Set RMT behind a proxy (with NTLM Auth)');
    # set the proxy setting to rmt.conf
    my $proxy_url = get_required_var('PROXY_SERVER');
    my $proxy_user = get_required_var('PROXY_USER');
    my $proxy_pw = get_required_var('PROXY_PASSWORD');

    $proxy_url = 'http:\/\/' . $proxy_url;
    my $rmt_conf = '/etc/rmt.conf';
    my $rmt_conf_bk = '/etc/rmt.conf.bk';

    # backup the rmt conf file
    assert_script_run("cp $rmt_conf $rmt_conf_bk");

    # update the rmt conf file with the proxy setting
    assert_script_run("sed -i 's/proxy: /proxy: $proxy_url/g' $rmt_conf");
    assert_script_run("sed -i 's/proxy_user: /proxy_user: $proxy_user/g' $rmt_conf");
    assert_script_run("sed -i 's/proxy_password: /proxy_password: $proxy_pw/g' $rmt_conf");
    assert_script_run("sed -i 's/proxy_auth: /proxy_auth: ntlm/g' $rmt_conf");
    assert_script_run("cat $rmt_conf");

    # verify the basic function of the rmt server
    my $test_product = get_required_var('PRODUCT_ALLM');
    assert_script_run("rmt-cli sync", timeout => 1800);
    assert_script_run("rmt-cli product enable $test_product");
    assert_script_run("rmt-cli product list | grep $test_product");

    # recover the test environment
    assert_script_run("mv $rmt_conf_bk $rmt_conf");

}

sub test_flags {
    return {fatal => 1};
}

1;
