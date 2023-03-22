# SUSE's openQA tests
#
# Copyright 2012-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: samba test conecting with Active Directory using adcli
# package: samba adcli samba-winbind krb5-client
#
# Maintainer: QE Core <qe-core@suse.de>
# Remote server: https://confluence.suse.com/display/qasle/AD+configuration+for+testing

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';
use Utils::Architectures;

## Fail fast when required variables are not present
my $AD_hostname = get_required_var("AD_HOSTNAME");
my $AD_ip = get_required_var("AD_HOST_IP");
my $AD_domain = get_required_var("AD_DOMAIN");
my $AD_workgroup = get_required_var("AD_WORKGROUP");
my $domain_joined = 0;

sub get_supportserver_file {
    my ($filename, $location) = @_;

    assert_script_run('curl -f ' . autoinst_url . "/data/supportserver/samba/$filename  > $location");
    assert_script_run("sed -i 's/\$AD_HOSTNAME/$AD_hostname/' $location");
    assert_script_run("sed -i 's/\$AD_HOST_IP/$AD_ip/' $location");
    assert_script_run("sed -i \"s/\\\$AD_DOMAIN_PASSWORD/\$AD_DOMAIN_PASSWORD/\" $location");
    assert_script_run("sed -i 's/\$AD_DOMAIN/$AD_domain/' $location");
    assert_script_run("sed -i 's/\$AD_WORKGROUP/$AD_workgroup/' $location");
}

sub samba_sssd_install {
    zypper_call('in expect samba adcli samba-winbind krb5-client sssd-ad');

    # sssd versions prior to 1.14 don't support conf.d
    # https://github.com/SSSD/sssd/issues/3289
    # 12-SP4 ships libini 1.2, and version 1.3.0 is required for this feature to be available in sssd
    my $sssd_config_location = "/etc/sssd/conf.d/suse.conf";
    $sssd_config_location = "/etc/sssd/sssd.conf" if is_sle('<=12-sp4');

    # Copy config files enviroment.
    get_supportserver_file("kinit.exp", '$HOME/kinit.exp');
    get_supportserver_file("smb.conf", "/etc/samba/smb.conf");
    get_supportserver_file("krb5.conf", "/etc/krb5.conf");
    get_supportserver_file("nsswitch.conf", "/etc/nsswitch.conf");
    get_supportserver_file("sssd/conf.d/suse.conf", $sssd_config_location);
    assert_script_run "chmod go-rwx $sssd_config_location";
    assert_script_run 'sed -i -E \'s/\tenable-cache(.*)(passwd|group)(.*)yes/\tenable-cache\1\2\3no/g\' /etc/nscd.conf';

    # Update the DNS configuration to use the Domain controller as primary source
    assert_script_run("echo NETCONFIG_DNS_STATIC_SEARCHLIST='$AD_hostname' >> /etc/sysconfig/network/config");
    assert_script_run("echo NETCONFIG_DNS_STATIC_SERVERS='$AD_ip' >> /etc/sysconfig/network/config");
    assert_script_run('netconfig update -f');
    validate_script_output("cat /etc/resolv.conf", qr/nameserver $AD_ip/, fail_message => "Domain controller not present in /etc/resolv.conf");

    # Ensure DNS name resolution works for the AD host
    assert_script_run("ping -c 2 $AD_hostname");
    assert_script_run("dig srv _kerberos._tcp.$AD_hostname", fail_message => "failed to resolved the required kerberos host entry for AD controller");
    assert_script_run("dig srv _ldap._tcp.$AD_hostname", fail_message => "failed to resolved the required LDAP SRV entry for AD controller");
}

sub join_domain {
    # Join the Active Directory via `kinit`
    script_retry("expect kinit.exp", retry => 3, timeout => 120, die => 1);
    validate_script_output("klist", qr/$AD_domain/, fail_message => "Kerberos ticket for domain not listed");

    # Retrying the adcli join is needed, due to https://bugs.freedesktop.org/show_bug.cgi?id=55487
    # Joining the domain can take some time.
    script_retry("adcli join -v --no-password --domain $AD_domain -U Administrator -C", delay => 30, retry => 3, timeout => 300, fail_message => "Joining AD domain failed (poo#96983)");
    record_info("adcli info", script_output("adcli info -D '$AD_domain' -S '$AD_hostname' -v"));

    # Test samba with AD
    # the wait_serial possibly could enter into a race condition, however for now this solution is good enough
    # if something is not working in the future: i.e authentication is not working, switching to using expect
    # would be a better idea
    # TODO: REMOVED: -S '$AD_hostname'
    assert_script_run("echo \"\$AD_DOMAIN_PASSWORD\" | net ads join --domain '$AD_domain' -U Administrator --no-dns-updates -i", timeout => 60, fail_message => "Error joining domain (poo#96986)");

    # Enable pam authentication
    assert_script_run "pam-config -a --mkhomedir";
    assert_script_run "pam-config -a --sss";

    foreach my $service (qw(smb nmb winbind sssd)) {
        systemctl("enable --now $service");
    }
    systemctl('restart nscd');
}

sub update_password {
    # Invalidate the password of the local computer account on AD
    script_retry("adcli update --verbose --computer-password-lifetime=0 --domain '$AD_domain'", retry => 3, delay => 60, fail_message => "Error invalidating local password");
    # Restore the password with --add-samba-data as requested by poo#91950
    script_retry("adcli update --verbose --computer-password-lifetime=0 --domain '$AD_domain' --add-samba-data", retry => 3, delay => 60, fail_message => "Error re-adding password with samba data");

    # Check the trust secret for the domain
    if (script_run("wbinfo -tP") != 0) {
        my $output = script_output('wbinfo -tP', proceed_on_failure => 1);

        # Check for bsc#1188575
        if ($output =~ "WBC_ERR_AUTH_ERROR") {
            die("wbinfo output failed") unless (is_sle('=12-SP3') || is_sle('=12-SP4'));
            record_soft_failure("bsc#1188575");
        }
    }
}

sub randomize_hostname {
    my $hostname = "openqa-" . random_string(length => 8);
    assert_script_run("hostnamectl set-hostname '$hostname'");
}

sub disable_ipv6 {
    assert_script_run('sysctl -w net.ipv6.conf.all.disable_ipv6=1');
}

sub enable_ipv6 {
    assert_script_run('sysctl -w net.ipv6.conf.all.disable_ipv6=0');
}

sub run {
    select_serial_terminal;

    # Ensure the required variables are set
    my $password = get_required_var("_SECRET_AD_DOMAIN_PASSWORD");
    define_secret_variable("AD_DOMAIN_PASSWORD", $password);

    samba_sssd_install();
    randomize_hostname();    # Prevent race condition with parallel test runs
    disable_ipv6();    # AD host is not reachable via IPv6 on some of our workers
    join_domain();
    $domain_joined = 1;

    # Verify users and groups from AD via winbind.
    # Note: The following checks are subject to sporadic failures (poo#96513)
    record_soft_failure("poo#96513 - Failed to get AD domain") if (script_run("wbinfo -D $AD_domain", timeout => 120) != 0);
    record_soft_failure("poo#96513 - Failed to get AD username") if (script_run("wbinfo -u | grep 'geekotest'", timeout => 120) != 0);
    record_soft_failure("poo#96513 - Failed to get AD groups") if (script_run("wbinfo -g | grep 'openqa'", timeout => 120) != 0);
    record_soft_failure("poo#96513 Failed to get AD user info for geekotest") if (script_run("wbinfo -i geekotest\@$AD_domain", timeout => 120) != 0);

    # poo#91950 (update password with adcli --add-samba-data option)
    update_password() unless (is_sle("=15") || is_sle("<12-SP4"));    # sle 15 and 12-SP3 do not support the `--add-samba-data` option

    assert_script_run("echo \"\$AD_DOMAIN_PASSWORD\" | net ads leave --domain '$AD_hostname' -U Administrator -i", fail_message => "Failed to leave the domain (poo#96986)");
    $domain_joined = 0;

    # For futher extensions
    # - smbclient //$AD_hostname/openQA as geekouser is permitted (read-only), but as berhard it is denied
    # - delete the computer OU after the test is done in post_run_hook
    # - test winbind (samba?) authentication
}

sub post_run_hook {
    my ($self) = shift;
    enable_ipv6();
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    enable_ipv6();

    script_run 'tar Jcvf samba_adcli.tar.xz /etc/sssd /var/log/samba /var/log/sssd /var/log/krb5';
    upload_logs('./samba_adcli.tar.xz');

    # Leave domain, if joined
    if ($domain_joined) {
        script_run("echo \"\$AD_DOMAIN_PASSWORD\" | net ads leave --domain '$AD_hostname' -U Administrator -i");
    }
}

1;
