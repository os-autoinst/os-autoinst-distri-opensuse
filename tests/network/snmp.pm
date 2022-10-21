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

sub run {
    select_serial_terminal;

    zypper_call 'in net-snmp';

    assert_script_run 'cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.back';
    assert_script_run 'echo "createUser bootstrap MD5 temp_password DES" >> /etc/snmp/snmpd.conf';
    assert_script_run 'echo "createUser bootstrap2 SHA temp_password AES" >> /etc/snmp/snmpd.conf';
    assert_script_run 'echo "rwuser bootstrap priv" >> /etc/snmp/snmpd.conf';
    assert_script_run 'echo "rwuser bootstrap2 priv" >> /etc/snmp/snmpd.conf';
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
    assert_script_run 'snmpget -v 3 -u bootstrap -l authPriv -a MD5 -x DES -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
    assert_script_run 'snmpget -v 3 -u bootstrap2 -l authPriv -a SHA -x AES -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';
    validate_script_output 'snmpget -v 3 -u bootstrap -l authPriv -a SHA -x AES -A wrong_password -X temp_password localhost sysLocation.0 || true', qr/Authentication failure/;

    record_info 'user create';
    assert_script_run 'snmpusm -u bootstrap -l authPriv -a MD5 -x DES -A temp_password -X temp_password localhost create demo bootstrap';
    assert_script_run 'snmpget -v 3 -u demo -l authPriv -a MD5 -x DES -A temp_password -X temp_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';

    record_info 'pass change';
    assert_script_run 'snmpusm -u demo -l authPriv -a MD5 -x DES -A temp_password -X temp_password localhost passwd temp_password new_password';
    assert_script_run 'snmpget -v 3 -u demo -l authPriv -a MD5 -x DES -A new_password -X new_password localhost 1.3.6.1.2.1.1.1.0 | grep Linux';

    record_info 'user config';
    assert_script_run 'mkdir ~/.snmp';
    assert_script_run 'echo "defSecurityName demo" > ~/.snmp/snmp.conf';
    assert_script_run 'echo "defSecurityLevel authPriv" >> ~/.snmp/snmp.conf';
    assert_script_run 'echo "defAuthType MD5" >> ~/.snmp/snmp.conf';
    assert_script_run 'echo "defPrivType DES" >> ~/.snmp/snmp.conf';
    assert_script_run 'echo "defAuthPassphrase new_password" >> ~/.snmp/snmp.conf';
    assert_script_run 'echo "defPrivPassphrase new_password" >> ~/.snmp/snmp.conf';
    assert_script_run 'snmpget localhost 1.3.6.1.2.1.1.1.0 | grep Linux';

    record_info 'snmp set';
    assert_script_run 'snmpset localhost sysLocation.0 s Earth';
    assert_script_run 'snmpget -v2c -c public localhost sysLocation.0 | grep Earth';

}
1;
