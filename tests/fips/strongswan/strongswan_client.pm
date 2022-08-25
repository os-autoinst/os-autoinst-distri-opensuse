# strongswan test
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: strongswan
# Summary: FIPS: strongswan_client
#          In fips mode, testing strongswan
#
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#108620, tc#1769974

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;

sub run {
    my $self = shift;
    select_console 'root-console';
    zypper_call 'in strongswan strongswan-hmac tcpdump';

    my $remote_ip = get_var('SERVER_IP', '10.0.2.101');
    my $local_ip = get_var('CLIENT_IP', '10.0.2.102');

    # Configure ipsec.conf
    my $ipsec_conf_temp = 'ipsec.conf.temp';
    my $ipsec_conf = '/etc/ipsec.conf';
    my $ipsec_conf_backup = '/etc/ipsec.conf.backup';
    my $ipsec_dir = '/etc/ipsec.d';
    my $server_work_dir = '/root/strongswan';

    # Workaround for bsc#1184144
    record_info('The next two steps are workaround for bsc#1184144');
    assert_script_run('mv /usr/lib/systemd/system/strongswan.service /usr/lib/systemd/system/strongswan-swanctl.service');
    assert_script_run('cp /usr/lib/systemd/system/strongswan-starter.service /usr/lib/systemd/system/strongswan.service');

    # Download the template of ipsec.conf
    assert_script_run("wget --quiet " . data_url("strongswan/$ipsec_conf_temp"));

    # Replace the vars %VARS% with correct value
    assert_script_run("sed -i 's/%LOCAL_IP%/$local_ip/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%REMOTE_IP%/$remote_ip/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%HOST_CERT_PEM%/host2.cert.pem/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%HOST%/host1/' $ipsec_conf_temp");

    # Replace ipsec.conf with the template file
    assert_script_run("cp $ipsec_conf $ipsec_conf_backup");
    assert_script_run("cp $ipsec_conf_temp $ipsec_conf");

    # Edit /etc/ipsec.secrets
    assert_script_run('echo ": RSA host2.pem" >> /etc/ipsec.secrets');

    mutex_create('STRONGSWAN_HOST2_UP');
    mutex_wait('STRONGSWAN_HOST1_SERVER_START');

    # Start stronswan daemon
    assert_script_run('rcstrongswan start');

    # Establish the ipsec tunnel
    assert_script_run('ipsec up host-host');

    mutex_create('STRONGSWAN_HOST2_START');

    validate_script_output('rcstrongswan status', sub { m/Active: active/ });

    validate_script_output('ipsec status', sub { m/Routed Connections/ && m/host-host\{\d\}:\s+$local_ip\/32\s===\s$remote_ip\/32/ && m/Security Associations.*1 up/ });

    validate_script_output('ipsec statusall', sub { m/host-host\[\d\]: IKEv2 SPIs/ && m/host-host\[\d\]: IKE proposal/ });

    mutex_wait('TCPDUMP_READY');

    assert_script_run("ping -c 5 $remote_ip");

    mutex_create('PING_DONE');
}

1;
