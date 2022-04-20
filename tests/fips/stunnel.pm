# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: stunnel tests in FIPS mode
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#108608, tc#1769815

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_tests;
use mmapi 'wait_for_children';

my $hostname = get_var('HOSTNAME');
# Set vnc password
my $password = '123456';

sub conf_stunnel_vnc {
    my $stunnel_config = <<EOF;
client = no
chroot = /var/lib/stunnel/
pid = /var/run/stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
cert = /etc/stunnel/stunnel.pem

fips =yes

[VNC]
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
        conf_stunnel_vnc;
        # Start the VNC server
        assert_script_run('mkdir -p ~/.vnc/');
        assert_script_run("vncpasswd -f <<<$password > ~/.vnc/passwd");
        assert_script_run('chmod 0600 ~/.vnc/passwd');
        assert_script_run('vncserver :5');
        assert_script_run('ss -tnlp | grep 5905');
        # Add lock for client
        mutex_create('stunnel');
        # Finish job
        wait_for_children;
        # Clean up
        assert_script_run('vncserver -kill :5');
        assert_script_run('rm -rf ~/.vnc/passwd');
    }
    else {
        mutex_wait('stunnel');
        # Copy the certificate from server
        exec_and_insert_password('scp -o StrictHostKeyChecking=no root@10.0.2.101:/etc/stunnel/stunnel.pem /etc/stunnel');
        # Configure stunnel
        conf_stunnel_vnc;
        # Turn to x11 and start "xterm"
        select_console('x11');
        x11_start_program('xterm');
        script_run('vncviewer 127.0.0.1:15905', 0);
        assert_screen('stunnel-vnc-auth');
        type_string $password;
        wait_still_screen 2;
        send_key 'ret';
        assert_screen('stunnel-server-desktop');
        send_key 'alt-f4';
        wait_still_screen 2;
        send_key 'alt-f4';
    }
}

1;
