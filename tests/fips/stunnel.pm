# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: stunnel tests in FIPS mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108608, tc#1769815

use base 'opensusebasetest';
use testapi;
use lockapi;
use utils;
use mm_tests;
use mmapi 'wait_for_children';
use version_utils 'package_version_cmp';

my $hostname = get_var('HOSTNAME');
# Set vnc password
my $message = 'Hello from the server';
# Set stunnel dir
my $stunnel_chroot_dir = "/var/run/stunnel";

sub conf_stunnel_netcat {
    my $stunnel_config = <<EOF;
chroot = $stunnel_chroot_dir
pid = /stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

client = no
cert = /etc/stunnel/stunnel.pem

fips = yes

[NETCAT]
accept = 15905
connect = 5905
EOF
    assert_script_run("echo '$stunnel_config' >>  /etc/stunnel/stunnel.conf");
    if ($hostname =~ /client|slave/) {
        assert_script_run q(sed -i 's/^client = no/client = yes/' /etc/stunnel/stunnel.conf);
        assert_script_run q(sed -i 's/^connect = 5905/connect = 10.0.2.101:15905/' /etc/stunnel/stunnel.conf);
    }
    assert_script_run("mkdir -p $stunnel_chroot_dir");
    assert_script_run("chown -R stunnel:nogroup $stunnel_chroot_dir");
    systemctl('start stunnel');
    systemctl('is-active stunnel');
    assert_script_run q(systemctl status stunnel | grep "FIPS mode enabled");
}

sub run {
    select_console 'root-console';
    zypper_call("in stunnel netcat-openbsd openssl");
    if ($hostname =~ /server|master/) {
        # Generate a self-signed certificate
        assert_script_run('mkdir stunnel_fips; cd stunnel_fips');
        assert_script_run
q(openssl req -new -x509 -newkey rsa:2048 -keyout stunnel.key -days 356 -out stunnel.crt -nodes -subj "/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=susetest.example.com");
        # Combine the private key and certificate together
        assert_script_run('cat stunnel.key stunnel.crt > stunnel.pem');
        # Copy the certificate to "/etc/stunnel"
        assert_script_run('cp stunnel.pem /etc/stunnel; cd');
        assert_script_run('chmod 600  /etc/stunnel/stunnel.pem');
        # Configure stunnel file
        conf_stunnel_netcat;
        # Add lock for client
        mutex_create('stunnel');
        # Start the netcat server. Huge timeout b/c will be closed upon client
        assert_script_run("echo $message|nc -l 127.0.0.1 5905", timeout => 300);
        # Finish job
        wait_for_children;
    } else {
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
