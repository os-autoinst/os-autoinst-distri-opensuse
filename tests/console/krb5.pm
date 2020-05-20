# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: MIT kerberus 5 test (krb5)
# Maintainer: Sergio Rafael Lemke <slemke@suse.cz>

# Setup a kdc (kdc is the Kerberos version 5 Authentication Service and Key Distribution Center)
# and run following commands: addprinc, getprincs, modprinc, getprinc, delprinc, listpols,
# addpol, modpol, delpol, getprivs, ktremove.
# system units tests (restart, stop, start, staus);
# rckadmind service start, stop, restart, status

use base 'consoletest';
use utils qw(zypper_call systemctl);
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call 'in krb5 krb5-server krb5-client';

    #Get the script that creates the kerberus server:
    script_run 'wget ' . data_url('console/setup-kerberos-server-3.pl');
    script_run 'chmod +x setup-kerberos-server-3.pl';

    #backup VM current status/setup:
    script_run 'cp /etc/hosts /etc/hosts-bkp';
    script_run 'cp /etc/hostname /etc/hostname-bkp';
    script_run 'hostname > /tmp/hostname';

    #setup FQDN hostname to successfully create krb5 server:
    script_run 'hostname openqa.kerberus.org';
    script_run 'echo "127.0.0.1 openqa.kerberus.org openqa" > /etc/hosts';
    script_run 'echo "openqa.kerberus.org" > /etc/hostname';

    #confirm FQDN:
    validate_script_output "hostname -f", sub { /openqa.kerberus.org/ };

    #Test Case 1439086: MIT Kerberos server:
    record_info 'Testcase 1439086:';
    assert_script_run './setup-kerberos-server-3.pl --realm openqa.kerberus.org -noy2kc --noinstall';

    #Fix realm address on krb5.cnf file:
    assert_script_run "sed -i 's/openqa.kerberus.org.kerberus.org/openqa.kerberus.org/g' /etc/krb5.conf";

    #Test Case 1439087: ssh with MIT Kerberos 5:
    record_info 'Testcase 1439087:';

    #kadmind starts the Kerberos administration server systemd unit:
    systemctl 'restart kadmind';
    systemctl 'stop kadmind';
    systemctl 'start kadmind';
    systemctl 'status kadmind';

    #krb5kdc is the Kerberos v.5 Auth. service and key distrib. center:
    systemctl 'restart krb5kdc';
    systemctl 'stop krb5kdc';
    systemctl 'start krb5kdc';
    systemctl 'status krb5kdc';

    script_run "mkdir -p /run/user/`id -u tester`/krb5cc";
    script_run "chown tester:users /run/user/`id -u tester`/krb5cc";

    # avoid failures in virtio-console due to unexpected PS1
    assert_script_run('echo "PS1=\'# \'" >> ~tester/.bashrc') if check_var('VIRTIO_CONSOLE', '1');

    #confirm we have no existing kinit tickets cache:
    script_run 'su - tester', 0;
    type_string "klist 2> /tmp/krb5\n";
    script_run 'logout',                                                       0;
    validate_script_output "grep -iEc \"credentials|not|found|no\" /tmp/krb5", sub { /1/ };

    #create kinit tickets cache for the user:
    script_run 'su - tester', 0;
    type_string "kinit\n";
    #just a fast paced and harmless pwd:
    type_string "1234wert\n";

    #confirm the users tickets cache is created, also confirm its on the FQDN:
    type_string "klist > /tmp/krb5-klist-cache 2> /dev/null\n";
    script_run 'logout',                                                                                         0;
    validate_script_output "grep -c \"krbtgt\/openqa.kerberus.org\@openqa.kerberus.org\" /tmp/krb5-klist-cache", sub { /1/ };

    #validate tickets cache output integrity:
    validate_script_output 'wc -l /tmp/krb5-klist-cache', sub { /6/ };

    #test the destroy kinit cache command:
    script_run 'su - tester', 0;
    type_string "kdestroy\n";
    type_string "klist 2> /tmp/krb5\n";
    script_run 'logout',                                                       0;
    validate_script_output "grep -iEc \"credentials|not|found|no\" /tmp/krb5", sub { /1/ };

    #test the service management script:
    assert_script_run 'rckadmind start';
    assert_script_run 'rckadmind stop';
    assert_script_run 'rckadmind start';
    assert_script_run 'rckadmind restart';
    assert_script_run 'rckadmind reload';
    assert_script_run 'rckadmind force-reload';
    validate_script_output "rckadmind status |grep -ic active", sub { /1/ };

    #cleanup/restore VM original state:
    script_run 'rm /tmp/krb5-klist-cache';
    script_run 'rm -f /var/lib/kerberos/krb5kdc/principal*';
    script_run 'mv /etc/hosts-bkp /etc/hosts';
    script_run 'mv /etc/hostname-bkp /etc/hostname';
    script_run 'rm /tmp/krb5';
    script_run 'hostname `cat /tmp/hostname`';
    script_run 'rm /tmp/hostname';

    #confirm hostname returned:
    validate_script_output "hostname", sub { /susetest/ };
}

1;
