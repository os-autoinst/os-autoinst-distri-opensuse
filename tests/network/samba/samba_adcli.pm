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
    zypper_call('in expect samba adcli samba-winbind krb5-client sssd-ad');

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

sub update_password {
    # Array @params contains tuples with [$params-for-adcli, $adcli-output-substring]
    # first  tuple: no extra parameter for adcli so '', look for the string 'WBC_ERR_AUTH_ERROR'
    # second tuple: add the extra parameter for adcli '--add-samba-data', look for the string 'succeeded'
    my @params = (['', 'WBC_ERR_AUTH_ERROR'], ['--add-samba-data', 'succeeded']);

    my $retries = 15;

    # First invalidate the password, then update/restore it using --add-samba-data
    for my $i (0 .. $#params) {
        my $cmd = 'adcli update --verbose --computer-password-lifetime=0 --domain geeko.com ' . $params[$i][0];

        # If the command fails, re-join as Administrator and retry the command (max 15 times)
        for (1 .. $retries) {
            my $ret = script_run($cmd);
            if ($ret eq "0") {
                # if the adcli command returned succesfully, stop retrying and break out of the loop
                last;
            } else {
                # adcli update failed, check bsc#1188390
                record_soft_failure("bsc#1188390");

                # Retrying the adcli join is needed, probably due to https://bugs.freedesktop.org/show_bug.cgi?id=55487
                script_retry 'adcli join -v -W --domain geeko.com -U Administrator -C', delay => 10, retry => 5, timeout => 60;
            }
        }

        # Check the trust secret for the domain
        my $output = script_output('wbinfo -tP', proceed_on_failure => 1);
        my $substr = $params[$i][1];
        if (index($output, $substr) == -1) {
            die("wbinfo output does not contain $substr");
        }
    }

    record_info('passw updated');
}

sub run {
    my $self = shift;
    # select_console 'root-console';
    $self->select_serial_terminal;
    samba_sssd_install;

    #Join the Active Directory
    assert_script_run "expect kinit.exp";

    # Retrying the adcli join is needed, probably due to https://bugs.freedesktop.org/show_bug.cgi?id=55487
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

    assert_script_run "expect -c 'spawn ssh -l geekouser\@geeko.com localhost -t;expect sword:;send Nots3cr3t\\n;expect geekouser>;send exit\\n;interact'";

    # poo#91950 (update machine password with adcli --add-samba-data option)
    update_password();

    assert_script_run "echo Nots3cr3t  | net ads leave --domain geeko.com -U Administrator -i";

    # For futher extensions
    # - Mount //GEEKO
    # - smbclient //10.162.30.119/openQA as geekouser will be denied, as berhard is the owner
    # - delete the computer OU after the test is done in post_run_hook
    # - add the post_fail_hook to upload all relevant logs
    # - test winbind (samba?) authentication

}


1;
