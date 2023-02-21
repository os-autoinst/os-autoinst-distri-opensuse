# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: net-snmp
# Summary: Test smtp server and client tools.
# Maintainer: QE Core <qe-core@suse.de>

use base 'opensusebasetest';
use warnings;
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'check_version';

sub run {
    select_serial_terminal;

    zypper_call 'in net-snmp';

    # version 5.7.3 on 15-SP2 and older use MD5/SHA & DES/AES protocols
    my $snmp_version = script_output("rpm -q --qf '%{version}' net-snmp");
    # on 15-SP3 is older release of 5.9.3 version which does not support new AES-192 AES-256
    my $snmp_release = script_output("rpm -q --qf '%{release}' net-snmp");
    my $new_snmp = check_version('>5.7.3', $snmp_version) && check_version('<150300', $snmp_release);
    record_info('net-snmp version', "$snmp_version-$snmp_release");
    my $auth_protocol = $new_snmp ? 'SHA-512' : 'MD5';
    my $auth_protocol2 = $new_snmp ? 'SHA-384' : 'SHA';
    my $priv_protocol = $new_snmp ? 'AES-256' : 'DES';
    my $priv_protocol2 = $new_snmp ? 'AES-192' : 'AES';

    assert_script_run 'cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.back';
    assert_script_run "echo \"createUser bootstrap $auth_protocol temp_password $priv_protocol\" >> /etc/snmp/snmpd.conf";
    assert_script_run "echo \"createUser bootstrap2 $auth_protocol2 temp_password $priv_protocol2\" >> /etc/snmp/snmpd.conf";
    assert_script_run 'echo "rwuser bootstrap priv" >> /etc/snmp/snmpd.conf';
    assert_script_run 'echo "rwuser bootstrap2 priv" >> /etc/snmp/snmpd.conf';
    if ($new_snmp) {
        assert_script_run 'echo "createUser bootstrap3 SHA-256 temp_password AES-192" >> /etc/snmp/snmpd.conf';
        assert_script_run 'echo "createUser bootstrap4 SHA-224 temp_password AES" >> /etc/snmp/snmpd.conf';
        assert_script_run 'echo "createUser bootstrap5 SHA temp_password AES" >> /etc/snmp/snmpd.conf';
        assert_script_run 'echo "rwuser bootstrap3 priv" >> /etc/snmp/snmpd.conf';
        assert_script_run 'echo "rwuser bootstrap4 priv" >> /etc/snmp/snmpd.conf';
        assert_script_run 'echo "rwuser bootstrap5 priv" >> /etc/snmp/snmpd.conf';
    }
    assert_script_run 'echo "rwuser demo priv" >> /etc/snmp/snmpd.conf';

    # remove syslocaton from config to allow overwriting via snmp
    assert_script_run 'sed -i -e "/^syslocation /d" /etc/snmp/snmpd.conf';

    systemctl 'start snmpd';

    record_info 'snmp get';
    record_info 'V1';
    assert_script_run 'snmpget -v 1 -c public localhost SNMPv2-MIB::sysDescr.0 | grep Linux';

    record_info 'V2c';
    assert_script_run 'snmpget -v 2c -c public localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
    validate_script_output 'snmpget -v2c -c badcommunity localhost sysLocation.0 || true', qr/Timeout: No Response from localhost/;

    record_info 'V3';
    assert_script_run "snmpget -v 3 -u bootstrap -l authPriv -a $auth_protocol -x $priv_protocol -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux";
    assert_script_run "snmpget -v 3 -u bootstrap2 -l authPriv -a $auth_protocol2 -x $priv_protocol2 -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux";
    if ($new_snmp) {
        assert_script_run 'snmpget -v 3 -u bootstrap3 -l authPriv -a SHA-256 -x AES-192 -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
        assert_script_run 'snmpget -v 3 -u bootstrap4 -l authPriv -a SHA-224 -x AES -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
        assert_script_run 'snmpget -v 3 -u bootstrap5 -l authPriv -a SHA -x AES -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
    }
    validate_script_output 'snmpget -v 3 -u bootstrap -l authPriv -a SHA -x AES -A wrong_password -X temp_password localhost sysLocation.0 || true', qr/Authentication failure/;

    record_info 'user create';
    assert_script_run "snmpusm -u bootstrap -l authPriv -a $auth_protocol -x $priv_protocol -A temp_password -X temp_password localhost create demo bootstrap";
    assert_script_run "snmpget -v 3 -u demo -l authPriv -a $auth_protocol -x $priv_protocol -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux";

    record_info 'pass change';
    assert_script_run "snmpusm -u demo -l authPriv -a $auth_protocol -x $priv_protocol -A temp_password -X temp_password localhost passwd temp_password new_password";
    assert_script_run "snmpget -v 3 -u demo -l authPriv -a $auth_protocol -x $priv_protocol -A new_password -X new_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux";

    record_info 'user config';
    assert_script_run 'mkdir ~/.snmp';
    assert_script_run 'echo "defSecurityName demo" > ~/.snmp/snmp.conf';
    assert_script_run 'echo "defSecurityLevel authPriv" >> ~/.snmp/snmp.conf';
    assert_script_run "echo \"defAuthType $auth_protocol\" >> ~/.snmp/snmp.conf";
    assert_script_run "echo \"defPrivType $priv_protocol\" >> ~/.snmp/snmp.conf";
    assert_script_run 'echo "defAuthPassphrase new_password" >> ~/.snmp/snmp.conf';
    assert_script_run 'echo "defPrivPassphrase new_password" >> ~/.snmp/snmp.conf';
    assert_script_run 'snmpget localhost 1.3.6.1.2.1.1.1.0 | grep Linux';

    record_info 'snmp set';
    assert_script_run 'snmpset localhost sysLocation.0 s Earth';
    assert_script_run 'snmpget -v2c -c public localhost sysLocation.0 | grep Earth';

}
1;
