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

# Global constants
my $stunnel_chroot_dir = "/var/run/stunnel";
my $server_ip = '10.0.2.101';
my $stunnel_port = 15905;
my $nc_base_port = 5905;
my $message = 'Hello from the server';

sub conf_stunnel_netcat {
    my ($is_client) = @_;

    # Determine dynamic config values based on role
    my $client_opt = $is_client ? 'yes' : 'no';
    # Client connects to Server IP:Port; Server connects to local NC port
    my $connect_tgt = $is_client ? "$server_ip:$stunnel_port" : "$nc_base_port";

    my $stunnel_config = <<EOF;
chroot = $stunnel_chroot_dir
pid = /stunnel.pid
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

client = $client_opt
cert = /etc/stunnel/stunnel.pem

fips = yes

[NETCAT]
accept = $stunnel_port
connect = $connect_tgt
EOF

    assert_script_run("echo '$stunnel_config' >>  /etc/stunnel/stunnel.conf");
    assert_script_run("mkdir -p $stunnel_chroot_dir");
    assert_script_run("chown -R stunnel:nogroup $stunnel_chroot_dir");
    systemctl('start stunnel');
    validate_script_output('systemctl status stunnel', sub { m/FIPS .* enabled/i });
}

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    my $is_server = ($hostname =~ /server|master/);

    select_console 'root-console';
    zypper_call("in stunnel netcat-openbsd openssl");

    if ($is_server) {
        # SERVER SIDE
        assert_script_run('mkdir -p stunnel_fips');
        my $folder_full_path = script_output('readlink -f stunnel_fips');
        assert_script_run(
qq(openssl req -new -x509 -newkey rsa:2048 -keyout $folder_full_path/stunnel.key -out $folder_full_path/stunnel.crt -days 365 -nodes -subj "/C=DE/ST=Berlin/L=Berlin/O=QA/OU=security/CN=susetest.example.com"),
            quiet => 1
        );

        assert_script_run("cat $folder_full_path/stunnel.key $folder_full_path/stunnel.crt > $folder_full_path/stunnel.pem");
        assert_script_run("cp $folder_full_path/stunnel.pem /etc/stunnel/");
        assert_script_run('chmod 600 /etc/stunnel/stunnel.pem');

        # Configure stunnel (Server mode)
        conf_stunnel_netcat(0);

        # Synchronize: Ready for client
        mutex_create('stunnel_ready');

        # Start netcat server.
        # This blocks until the client connects and sends data, or times out.
        assert_script_run("echo '$message' | nc -l 127.0.0.1 $nc_base_port", timeout => 300);

    } else {
        # CLIENT SIDE
        # Wait for server to set up keys and start stunnel
        mutex_wait('stunnel_ready');

        # Retrieve certificate from server
        exec_and_insert_password("scp -o StrictHostKeyChecking=no root\@$server_ip:/etc/stunnel/stunnel.pem /etc/stunnel/");
        assert_script_run('chmod 600 /etc/stunnel/stunnel.pem');

        # Configure stunnel (Client mode)
        conf_stunnel_netcat(1);

        # Send data through stunnel
        # -4: IPv4, -n: No DNS, -N: Shutdown on EOF, -q 1: Quit after EOF
        validate_script_output(
            "echo | nc -4nNq 1 127.0.0.1 $stunnel_port",
            sub { m/$message/ },
            timeout => 300
        );
    }
}

1;
