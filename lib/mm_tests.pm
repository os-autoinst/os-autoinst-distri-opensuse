# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: functions are commonly used for multi-machine tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package mm_tests;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;
use utils;
use mm_network;
use version_utils ':SCENARIO';

our @EXPORT = qw(
  configure_static_network
  configure_stunnel
);

sub configure_static_network {
    my $ip = shift;

    configure_default_gateway;
    configure_static_ip(ip => $ip);
    configure_static_dns(get_host_resolv_conf());
    restart_networking();
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager -o short-precise >/dev/$serialdev";
}

sub configure_stunnel {
    my $is_server = shift;

    # Fetch and copy self-signed certificate of stunnel
    assert_script_run 'wget --quiet ' . data_url('openssl/stunnel.pem');
    assert_script_run 'cp stunnel.pem /etc/stunnel';

    # Configure stunnel for vnc server/client
    if (!$is_server) {
        assert_script_run "sed -i 's/^client = no/client = yes/' /etc/stunnel/stunnel.conf";
    }
    my $conf = get_var('FIPS_ENABLED') || get_var('FIPS') ? "fips = yes\n" : '';
    $conf .= "[VNC]\naccept = 15905\nconnect = ";
    $conf .= $is_server ? "5905\n" : "10.0.2.1:15905\n";
    assert_script_run "echo \"$conf\" >> /etc/stunnel/stunnel.conf";
    assert_script_run 'chown -R stunnel:nogroup /var/lib/stunnel';

    systemctl('start stunnel.service');
}

1;
