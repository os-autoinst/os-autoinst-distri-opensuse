# openssl fips test
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: strongswan
# Summary: FIPS: strongswan_server
#          In fips mode, testing strongswan
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108620, tc#1769974, poo#111581

use base 'consoletest';
use testapi;
use utils;
use lockapi;
use mmapi qw(wait_for_children get_children);
use version_utils qw(package_version_cmp is_sle);

sub run {
    my $self = shift;
    select_console 'root-console';
    zypper_call 'in strongswan strongswan-hmac tcpdump';
    zypper_call 'in strongswan-mysql strongswan-sqlite wget' if is_sle('>=16');

    my ($version, $conf, $conf_temp, $conf_backup, $conf_dir) = '';
    my ($ca_cert_dir, $priv_dir, $cert_dir, $ipsec) = '';

    my $test_dir = '/root/strongswan';
    my $ca_pem = 'ca.pem';
    my $ca_cert_pem = 'ca.cert.pem';
    my $host1_cert_pem = 'host1.cert.pem';
    my $host2_cert_pem = 'host2.cert.pem';
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
    # on SLE >= 15 we have version 5.8.x or greater, which includes the fix.
    validate_script_output('rpm -q strongswan --changelog', sub { m/bsc#1195919/ }) if is_sle('<15');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -pkeyopt mode:EXTRACT_ONLY -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt key:ff -pkeyopt salt:ff -pkeyopt mode:EXTRACT_AND_EXPAND -hexdump');
    assert_script_run('openssl pkeyutl -kdf HKDF -kdflen 48 -pkeyopt md:SHA256 -pkeyopt info:ff -pkeyopt key:ff -pkeyopt mode:EXPAND_ONLY -hexdump');

    $version = script_output("rpm -q --qf '%{version}' strongswan");

    if (package_version_cmp($version, '6.0.0') < 0) {
        # Workaround for bsc#1184144
        record_info('The next two steps are workaround for bsc#1184144');
        assert_script_run('mv /usr/lib/systemd/system/strongswan.service /usr/lib/systemd/system/strongswan-swanctl.service');
        assert_script_run('cp /usr/lib/systemd/system/strongswan-starter.service /usr/lib/systemd/system/strongswan.service');
        $ipsec = 'ipsec';
        $conf = '/etc/ipsec.conf';
        $conf_temp = 'ipsec.conf.temp';
        $conf_backup = '/etc/ipsec.conf.bak';
        $conf_dir = '/etc/ipsec.d';
        $ca_cert_dir = "$conf_dir/cacerts";
        $cert_dir = "$conf_dir/certs";
        $priv_dir = "$conf_dir/private";
    } else {
        $conf_dir = '/etc/swanctl';
        $conf = "$conf_dir/swanctl.conf";
        $conf_temp = 'swanctl.conf.temp';
        $conf_backup = "$conf_dir/swanctl.conf.bak";
        $ca_cert_dir = "$conf_dir/x509ca";
        $cert_dir = "$conf_dir/x509";
        $priv_dir = "$conf_dir/private";
    }

    # Create private CA key and self-signed certificate
    assert_script_run("mkdir $test_dir && cd $test_dir");
    assert_script_run("pki --gen --type rsa --size 2048 --outform pem > $ca_pem");
    assert_script_run("$ipsec pki --self --in $ca_pem --dn \"C=DE, O=SUSEQA, CN=CA\" --ca --outform pem > $ca_cert_pem");

    # Generate key and certificate for the hosts
    for my $host (qw(host1 host2)) {
        assert_script_run("pki --gen --type rsa --size 2048 --outform pem > $host.pem");
        assert_script_run("pki --pub --in $host.pem | $ipsec pki --issue --cacert $ca_cert_pem --cakey $ca_pem --dn \"C=DE, O=SUSEQA, CN=$host\" --outform pem > $host.cert.pem");
    }

    # Copy the keys and certificates to specific directories
    assert_script_run("mkdir -p $conf_dir $ca_cert_dir $cert_dir $priv_dir");
    assert_script_run("cp -pv $ca_cert_pem $ca_cert_dir");
    assert_script_run("cp -pv $host1_cert_pem $host2_cert_pem $cert_dir");
    assert_script_run("cp -pv host1.pem $priv_dir");

    # Download the template of ipsec.conf
    assert_script_run("wget --quiet " . data_url("strongswan/$conf_temp"));

    # Replace the vars %VARS% with correct value
    if (package_version_cmp($version, '6.0.0') < 0) {
        # only in ipsec.conf
        assert_script_run("sed -i 's/%LOCAL_IP%/$local_ip/' $conf_temp");
    }
    assert_script_run("sed -i 's/%REMOTE_IP%/$remote_ip/' $conf_temp");
    assert_script_run("sed -i 's/%HOST_CERT_PEM%/$host1_cert_pem/' $conf_temp");
    assert_script_run("sed -i 's/%HOST%/host2/' $conf_temp");

    # Create a backup of the appropriate config file
    # and replace it with the filled-in template file
    assert_script_run("cp $conf $conf_backup");
    assert_script_run("cp $conf_temp $conf");

    my $children = get_children();
    mutex_wait('STRONGSWAN_HOST2_UP', (keys %$children)[0]);

    # Prepare dirs and copy the keys, certificates to the second host
    exec_and_insert_password("ssh -o StrictHostKeyChecking=no root\@$remote_ip \"mkdir -p $conf_dir $ca_cert_dir $cert_dir $priv_dir\"");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no ca.cert.pem root\@$remote_ip:$ca_cert_dir/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host1.cert.pem root\@$remote_ip:$cert_dir/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host2.cert.pem root\@$remote_ip:$cert_dir/");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no host2.pem root\@$remote_ip:$priv_dir/");

    mutex_create('STRONGSWAN_HOST1_SECRETS_COPIED');

    if (package_version_cmp($version, '6.0.0') < 0) {
        # Edit /etc/ipsec.secrets
        assert_script_run('echo ": RSA host1.pem" >> /etc/ipsec.secrets');
    }

    systemctl 'start strongswan';

    mutex_create('STRONGSWAN_HOST1_SERVER_START');

    mutex_wait('STRONGSWAN_HOST2_START', (keys %$children)[0]);

    systemctl 'is-active strongswan';

    # Check the tcpdump result
    my $tcpdump_log_file = '/tmp/tcpdump.log';
    my $net_device = script_output("ip route | awk '/default/ {print \$5}'");
    my $pid = background_script_run("tcpdump -n -i $net_device -e \"esp\" -vv > $tcpdump_log_file 2>&1");
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
