# SUSE's rsyslog tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test rsyslog server and client with TLS enabled.
#    This is a multi-machine test, which requires two nodes
#    with tap network for the rsyslog server and client.
#    In this case, the rsyslog server is accessible as 10.0.2.1
#    and listening on tcp port 10514.
#    The rsyslog server will create mutex 'rsyslog_server' to
#    notify the client it is ready to receive message. Then
#    wait for a test message from the client.
#    The rsyslog client will send a message to the server
#    and then create another mutex 'rsyslog_client' to notify
#    the server that client is done.
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use base "consoletest";
use lockapi;
use testapi;
use mmapi;
use mm_network;

sub run {
    my $self = shift;

    select_console 'root-console';

    my $is_rsyslog_server = get_var('RSYSLOG_SERVER');
    my $rsyslog_server_ip = "10.0.2.1/24";
    my $rsyslog_client_ip = "10.0.2.50/24";
    my $my_static_ip      = $is_rsyslog_server ? $rsyslog_server_ip : $rsyslog_client_ip;
    my $client_message    = "Test message from client";
    my $setup_script      = "zypper -n in rsyslog rsyslog-module-gtls\n";

    configure_default_gateway;
    configure_static_ip($my_static_ip);

    $setup_script .= "curl -f -v " . autoinst_url . "/data/openssl/ca-cert.pem > /etc/rsyslog.d/ca-cert.pem\n";
    if ($is_rsyslog_server) {
        $setup_script .= "curl -f -v " . autoinst_url . "/data/openssl/server-cert.pem > /etc/rsyslog.d/server-cert.pem\n";
        $setup_script .= "curl -f -v " . autoinst_url . "/data/openssl/server-key.pem > /etc/rsyslog.d/server-key.pem\n";
        $setup_script .= "curl -f -v " . autoinst_url . "/data/rsyslog/rsyslog-server.conf > /etc/rsyslog.d/rsyslog-server.conf\n";
        $setup_script .= "mkdir -p /var/log/rsyslog-custom/\n";
    }
    else {
        my ($server_ip_no_mask, $mask) = split('/', $rsyslog_server_ip);
        $setup_script
          .= "curl -f -v "
          . autoinst_url
          . "/data/rsyslog/rsyslog-client.conf | sed -e 's/#RSYSLOG_SERVER#/"
          . $server_ip_no_mask
          . "/g' > /etc/rsyslog.d/rsyslog-client.conf\n";
        $setup_script .= "mkdir -p /var/spool/rsyslog\n";
    }
    $setup_script .= "systemctl restart rsyslog.service\n";
    $setup_script .= "systemctl status rsyslog.service\n";
    $setup_script .= "SuSEfirewall2 stop\n";

    print $setup_script;
    script_output($setup_script, 300);

    if ($is_rsyslog_server) {
        my $children = get_children();
        my $child_id = (keys %$children)[0];
        mutex_create('rsyslog_server');
        mutex_lock('rsyslog_client', $child_id);

        my ($client_ip_no_mask, $mask) = split('/', $rsyslog_client_ip);
        assert_script_run "grep '$client_message' /var/log/rsyslog-custom/${client_ip_no_mask}.log";

        wait_for_children;
    }
    else {
        mutex_lock('rsyslog_server');
        mutex_unlock('rsyslog_server');
        assert_script_run "logger '$client_message'";
        mutex_create('rsyslog_client');
    }
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
