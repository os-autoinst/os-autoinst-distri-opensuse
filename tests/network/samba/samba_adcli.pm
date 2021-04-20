# SUSE's openQA tests
#
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: samba test conecting with Active Directory using adcli
# package: samba adcli samba-winbind krb5-client
#
# Maintainer: Marcelo Martins <mmartins@suse.com>

use strict;
use warnings;
use base "consoletest";
use repo_tools qw(add_qa_head_repo add_qa_web_repo);
use testapi;
use utils;

my $AD_hostname = 'win2019dcadprovider.phobos.qa.suse.de';
my $AD_ip       = '10.162.30.119';

sub samba_sssd_install {
    zypper_call('in  samba adcli samba-winbind krb5-client');
    #Copy config files enviroment.
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/smb.conf  >/etc/samba/smb.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/krb5.conf  >/etc/krb5.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/nsswitch.conf  >/etc/nsswitch.conf";
    #assert_script_run("echo '10.0.2.102 susetest.geeko.com susetest' > /etc/hosts");
    #assert_script_run("echo '10.0.2.101 win-r70413psjm4.geeko.com win-r70413psjmn4' >> /etc/hosts");
    script_run('echo NETCONFIG_DNS_STATIC_SEARCHLIST="geeko.com" >> /etc/sysconfig/network/config');
    script_run('echo NETCONFIG_DNS_STATIC_SERVERS="' . $AD_ip . '" >> /etc/sysconfig/network/config');
    assert_script_run('netconfig update -f');
}

sub run {
    my $self = shift;
    #select_console 'root-console';
    $self->select_serial_terminal;
    samba_sssd_install;

    #Join the Active Directory
    script_run 'kinit Administrator', quiet => 1;
    wait_serial 'Password for Administrator@GEEKO.COM:';
    enter_cmd "Nots3cr3t";
    assert_script_run 'adcli join -v -W --domain geeko.com -U Administrator -C', fail_message => 'Host down?';
    #Verify if machine already added
    assert_script_run "adcli info -D geeko.com  -S $AD_hostname -v";

    #test samba with AD
    assert_script_run "klist";
    script_run "net ads join -U Administrator", quiet => 1;
    wait_serial "Set Administrator's password:";
    enter_cmd "Nots3cr3t";
    systemctl('restart smb nmb winbind');
    #systemctl('restart nmb');
    #systemctl('restart winbind');
    #Enable pam authentication
    assert_script_run "pam-config -a --winbind";
    #Verify users and groups  from AD
    assert_script_run "wbinfo -u";
    assert_script_run "wbinfo -g";
    assert_script_run "wbinfo -D geeko.com";
    assert_script_run "wbinfo -i geekouser\@geeko.com";
    assert_script_run "wbinfo -i Administrator\@geeko.com";
}

1;
