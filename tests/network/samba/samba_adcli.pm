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
use testapi;
use utils;
use version_utils 'is_sle';

my $AD_hostname = 'win2019dcadprovider.phobos.qa.suse.de';
my $AD_ip       = '10.162.30.119';

sub samba_sssd_install {
    zypper_call('in samba adcli samba-winbind krb5-client sssd-ad');

    # sssd versions prior to 1.14 don't support conf.d
    # https://github.com/SSSD/sssd/issues/3289
    # 12-SP4 ships libini 1.2, and version 1.3.0 is required for this feature to be available in sssd
    my $sssd_config_location = "/etc/sssd/conf.d/suse.conf";
    $sssd_config_location = "/etc/sssd/sssd.conf" if is_sle('<=12-sp4');

    record_info($sssd_config_location);

    #Copy config files enviroment.
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/kinit.exp  > ~/kinit.exp";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/smb.conf  >/etc/samba/smb.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/krb5.conf  >/etc/krb5.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/nsswitch.conf  >/etc/nsswitch.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/samba/sssd/conf.d/suse.conf  >$sssd_config_location";
    assert_script_run "chmod go-rwx $sssd_config_location";
    assert_script_run 'sed -i -E \'s/\tenable-cache(.*)(passwd|group)(.*)yes/\tenable-cache\1\2\3no/g\' /etc/nscd.conf';

    # ensure we can resolve the ip addresses of the Active Directory Server
    script_run('echo NETCONFIG_DNS_STATIC_SEARCHLIST="geeko.com" >> /etc/sysconfig/network/config');
    script_run('echo NETCONFIG_DNS_STATIC_SERVERS="' . $AD_ip . '" >> /etc/sysconfig/network/config');
    assert_script_run('netconfig update -f');

    script_run('dig srv _kerberos._tcp.geeko.com');
    script_run('dig srv _ldap._tcp.geeko.com');
}

sub run {
    my $self = shift;
    # select_console 'root-console';
    $self->select_serial_terminal;
    samba_sssd_install;

    #Join the Active Directory
    assert_script_run "expect kinit.exp";

    script_retry 'adcli join -v -W --domain geeko.com -U Administrator -C', delay => 10, retry => 5, timeout => 60;

    #Verify if machine already added
    assert_script_run "adcli info -D geeko.com  -S $AD_hostname -v";

    #test samba with AD
    # the wait_serial possibly could enter into a race condition, however for now this solution is good enough
    # if something is not working in the future: i.e authentication is not working, switching to using expect
    # would be a better idea
    assert_script_run "klist";
    assert_script_run "echo Nots3cr3t  | net ads join --domain geeko.com -U Administrator --no-dns-updates -i";

    #systemctl('restart nmb');
    #systemctl('restart winbind');
    #Enable pam authentication
    # assert_script_run "pam-config -a --winbind"; We'll only use sss to authenticate for now
    assert_script_run "pam-config -a --mkhomedir";
    assert_script_run "pam-config -a --sss";

    foreach my $service (qw(smb nmb winbind sssd)) {
        systemctl("enable --now $service");
    }

    systemctl('restart nscd');
    #Verify users and groups  from AD
    assert_script_run "wbinfo -u | grep foursixnine";
    assert_script_run "wbinfo -g | grep dnsupdateproxy";
    assert_script_run "wbinfo -D geeko.com";
    assert_script_run "wbinfo -i geekouser\@geeko.com";
    assert_script_run "wbinfo -i Administrator\@geeko.com";

    # Testing login via sssd
    # avoid harmless failures in virtio-console due to unexpected PS1
    assert_script_run("chmod 666 /dev/$serialdev");    # avoid geekouser not being able to use $serialdev


    # We want to test that GPO policies for computers are working when they are comming from AD
    # for that we set up a policy where user Bernhard is not allowed to login using terminal services
    # which for linux translates in ssh (for instance), but will allow him to connect using a local
    # connection which is why we're logging in as geekouser first, and then logging in as bernhard locally
    # via su - bernhard
    #
    # All these tests belong to the SSSD + AD side of testing
    # net ads join & leave commands belong to samba section furthermore this test is either to be split
    # or extended with better separation of domain

    # bernhard is denied remote login
    enter_cmd "expect -c 'spawn ssh -l bernhard\@geeko.com localhost -t;expect Password:;send Nots3cr3t\\n;interact'";
    sleep 10;                                                             # sleep 10 seconds, to wait for password validation and stuff
    assert_script_run "whoami | grep root";                               # GPO in the AD dictates that bernhard can't login over ssh
    record_info("ssh login: DENIED", "bernhard can't login remotely");    # if the domain user is known to the system, user bernhard can login further ahead
                                                                          # sssd/pam will first look in the domain, and that will deny bernhard a login
    assert_script_run "getent passwd bernhard";

    # geekouser is allowed to login
    # geekouser's login should be extended to log in as bernhard to check that local login is also working
    enter_cmd "expect -c 'spawn ssh -l geekouser\@geeko.com localhost -t;expect sword:;send Nots3cr3t\\n;interact'";
    assert_script_run 'echo $SSH_TTY | grep pts';
    assert_script_run 'ps ux | egrep ".* \? .* sshd\:"';
    assert_script_run "whoami | grep geekouser";
    record_info("ssh: ALLOWED");

    # Login as bernhard now
    enter_cmd "expect -c 'spawn su - bernhard;expect sword:;send Nots3cr3t\\n;interact'";
    assert_script_run 'echo $SSH_TTY | grep "^$"';
    assert_script_run "whoami | grep bernhard";
    record_info("local: PASS", "bernhard logged in");

    enter_cmd "logout";    # leaves bernhard's session
    assert_script_run "whoami | grep geekouser";

    enter_cmd "logout";                        # leaves geekouser's session and terminates the expect command calls started above
    assert_script_run "whoami | grep root";    # we're back to root, now we can leave the domain

    # Leave the domain
    assert_script_run "echo Nots3cr3t  | net ads leave --domain geeko.com -U Administrator -i";

    # For futher extensions
    # - Mount //GEEKO
    # - smbclient //10.162.30.119/openQA as geekouser will be denied, as berhard is the owner
    # - delete the computer OU after the test is done in post_run_hook
    # - test winbind (samba?) authentication

}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    $self->select_serial_terminal;
    script_run 'tar Jcvf samba_adcli.tar.xz /etc/sssd /var/log/samba /var/log/sssd /var/log/krb5';
    upload_logs('./samba_adcli.tar.xz');
}

1;
