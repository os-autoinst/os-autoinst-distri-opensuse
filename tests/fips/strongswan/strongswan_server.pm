# openssl fips test
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: strongswan
# Summary: FIPS: strongswan_server
#          In fips mode, testing strongswan
#
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#108620, tc#1769974, poo#111581

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi qw(wait_for_children get_children);
use version_utils 'package_version_cmp';

sub run {
    my $self = shift;
    select_console 'root-console';
    zypper_call 'in strongswan strongswan-hmac tcpdump';

    my $test_dir = '/root/strongswan';
    my $ca_pem = 'ca.pem';
    my $ca_cert_pem = 'ca.cert.pem';
    my $host1_cert_pem = 'host1.cert.pem';
    my $host2_cert_pem = 'host2.cert.pem';
    my $ipsec_dir = '/etc/ipsec.d';
    my $local_ip = get_var('SERVER_IP', '10.0.2.101');
    my $remote_ip = get_var('CLIENT_IP', '10.0.2.102');

    # Check version
    my $output = script_output('rpm -qa | grep strongswan');
    foreach my $pkg (split(/\n/, $output)) {
        my $version = script_output("rpm -q --qf '%{version}' $pkg");
        if (package_version_cmp($version, '5.9.0') < 0) {
            record_info("$pkg", "The version of $pkg is lower than expected", result => 'softfail');
        }
    }

    # Integrate hkdf function test
    # POO: https://progress.opensuse.org/issues/111581
    validate_script_output('rpm -q strongswan --changelog', sub { m/bsc#1195919/ });
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -pkeyopt mode:EXTRACT_ONLY -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -pkeyopt mode:EXTRACT_AND_EXPAND -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt info:ff -pkeyopt key:ff -pkeyopt mode:EXPAND_ONLY -hexdump');

    # Workaround for bsc#1184144
    record_info('The next two steps are workaround for bsc#1184144');
    assert_script_run('mv /usr/lib/systemd/system/strongswan.service /usr/lib/systemd/system/strongswan-swanctl.service');
    assert_script_run('cp /usr/lib/systemd/system/strongswan-starter.service /usr/lib/systemd/system/strongswan.service');

    # Create private CA key and self-signed certificate
    assert_script_run("mkdir $test_dir && cd $test_dir");
    assert_script_run("pki --gen --type rsa --size 2048 --outform pem > $ca_pem");
    assert_script_run("ipsec pki --self --in $ca_pem --dn \"C=CN, O=SUSEQA, CN=CA\" --ca --outform pem > $ca_cert_pem");

    # Generate key and certificate for the hosts
    for my $host (qw(host1 host2)) {
        assert_script_run("pki --gen --type rsa --size 2048 --outform pem > $host.pem");
        assert_script_run("pki --pub --in $host.pem | ipsec pki --issue --cacert $ca_cert_pem --cakey $ca_pem --dn \"C=CN, O=SUSEQA, CN=$host\" --outform pem > $host.cert.pem");
    }

    # Copy the keys and certificates to specific directories
    assert_script_run("cp -pv $ca_cert_pem $ipsec_dir/cacerts");
    assert_script_run("cp -pv $host1_cert_pem $host2_cert_pem $ipsec_dir/certs");
    assert_script_run("cp -pv host1.pem $ipsec_dir/private");

    my $ipsec_conf_temp = 'ipsec.conf.temp';
    my $ipsec_conf = '/etc/ipsec.conf';
    my $ipsec_conf_backup = '/etc/ipsec.conf.backup';

    # Download the template of ipsec.conf
    assert_script_run("wget --quiet " . data_url("strongswan/$ipsec_conf_temp"));

    # Replace the vars %VARS% with correct value
    assert_script_run("sed -i 's/%LOCAL_IP%/$local_ip/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%REMOTE_IP%/$remote_ip/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%HOST_CERT_PEM%/$host1_cert_pem/' $ipsec_conf_temp");
    assert_script_run("sed -i 's/%HOST%/host2/' $ipsec_conf_temp");

    # Replace ipsec.conf with the template file
    assert_script_run("cp $ipsec_conf $ipsec_conf_backup");
    assert_script_run("cp $ipsec_conf_temp $ipsec_conf");

    my $children = get_children();
    mutex_wait('STRONGSWAN_HOST2_UP', (keys %$children)[0]);

    # Copy the keys and certificates to the second host
    exec_and_insert_password("scp -o StrictHostKeyChecking=no ca.cert.pem root\@$remote_ip:$ipsec_dir/cacerts/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host1.cert.pem root\@$remote_ip:$ipsec_dir/certs/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host2.cert.pem root\@$remote_ip:$ipsec_dir/certs/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host2.pem root\@$remote_ip:$ipsec_dir/private/");

    # Edit /etc/ipsec.secrets
    assert_script_run('echo ": RSA host1.pem" >> /etc/ipsec.secrets');

    # Start stronswan daemon
    assert_script_run('rcstrongswan start');

    mutex_create('STRONGSWAN_HOST1_SERVER_START');

    mutex_wait('STRONGSWAN_HOST2_START', (keys %$children)[0]);

    validate_script_output('rcstrongswan status', sub { m/Active: active/ });

    # Check the tcpdump result
    my $tcpdump_log_file = '/tmp/tcpdump.log';
    my $pid = background_script_run("tcpdump -n -i eth0 -e \"esp\" -vv > $tcpdump_log_file 2>&1");
    mutex_create('TCPDUMP_READY');
    mutex_wait('PING_DONE', (keys %$children)[0]);
    assert_script_run("kill -15 $pid");

    my $num = script_output("cat $tcpdump_log_file | grep '$remote_ip > $local_ip: ESP' | wc -l");
    if ($num == 5) {
        record_info('tcpdump result is correct');
    }
    else {
        record_info('tcpdump result is wrong', result => 'fail');
        $self->result('fail');
    }

    upload_logs('/tmp/tcpdump.log');

    wait_for_children;
}

1;
