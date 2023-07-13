# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: stunnel tests in FIPS mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108608, tc#1769815

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_tests;
use mmapi 'wait_for_children';
use version_utils 'package_version_cmp';

my $hostname = get_var('HOSTNAME');
# Set vnc password
my $message = 'Hello from the server';

sub conf_stunnel_netcat {
    my $stunnel_config = <<EOF;
client = no
chroot = /var/lib/stunnel/
pid = /var/run/stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
cert = /etc/stunnel/stunnel.pem

fips =yes

[NETCAT]
accept = 15905
connect = 5905
EOF
    assert_script_run("echo '$stunnel_config' >>  /etc/stunnel/stunnel.conf");
    if ($hostname =~ /client|slave/) {
        assert_script_run q(sed -i 's/^client = no/client = yes/' /etc/stunnel/stunnel.conf);
        assert_script_run q(sed -i 's/^connect = 5905/connect = 10.0.2.101:15905/' /etc/stunnel/stunnel.conf);
    }
    assert_script_run('chown -R stunnel:nogroup /var/lib/stunnel');
    systemctl('start stunnel');
    systemctl('is-active stunnel');
    assert_script_run q(grep 'stunnel:.*FIPS mode enabled' /var/log/messages);
}

sub run {
    select_console 'root-console';
    # Package version check
    my $pkg_list = {stunnel => '5.62'};
    zypper_call("in " . join(' ', keys %$pkg_list));
    package_upgrade_check($pkg_list);
    if ($hostname =~ /server|master/) {
        # Generate a self-signed certificate
        assert_script_run('mkdir stunnel_fips; cd stunnel_fips');
        assert_script_run
q(openssl req -new -x509 -newkey rsa:2048 -keyout stunnel.key -days 356 -out stunnel.crt -nodes -subj "/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=susetest.example.com");
        # Combine the private key and certificate together
        assert_script_run('cat stunnel.key stunnel.crt > stunnel.pem');
        # Copy the certificate to "/etc/stunnel"
        assert_script_run('cp stunnel.pem /etc/stunnel; cd');
        # Configure stunnel file
        conf_stunnel_netcat;
        # Add lock for client
        mutex_create('stunnel');
        # Start the netcat server. Huge timeout b/c will be closed upon client
        assert_script_run("echo $message|nc -l 127.0.0.1 5905", timeout => 300);
        # Finish job
        wait_for_children;
    }
    else {
        mutex_wait('stunnel');
        # Copy the certificate from server
        exec_and_insert_password('scp -o StrictHostKeyChecking=no root@10.0.2.101:/etc/stunnel/stunnel.pem /etc/stunnel');
        # Configure stunnel
        conf_stunnel_netcat;
        # huge timeout b/c will be closed upon client
        validate_script_output 'echo | nc -4nNq 1 127.0.0.1 15905', sub { m/$message/ }, timeout => 300;
    }
}

1;
