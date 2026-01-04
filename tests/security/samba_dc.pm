# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: Samba Domain Controller Tests
# Summary: setup a Samba DC server
#  - install samba and necessary packages
#  - setup samba as AD DC
#  - start samba services
#
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use lockapi;
use utils qw(zypper_call systemctl script_retry random_string);
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use feature 'signatures';
no warnings 'experimental::signatures';

use constant {
    DOMAIN => 'EXAMPLE',
    REALM => 'EXAMPLE.INTERNAL',
    PASSWORD => 'Passw0rd',
};

# ------------------------ common entry point -------------------------------

sub run ($self) {
    my $hostname = get_var('HOSTNAME');
    select_serial_terminal;

    ($hostname eq 'client') ? run_client() : run_server();
}

sub post_fail_hook ($self) {
    $self->SUPER::post_fail_hook;
    script_run 'tar Jcvf samba_dc.tar.xz /etc/sssd /var/log/samba /var/log/sssd /var/log/krb5';
    upload_logs('./samba_dc.tar.xz');
}

sub disable_ipv6 {
    assert_script_run('sysctl -w net.ipv6.conf.all.disable_ipv6=1');
}

sub enable_ipv6 {
    assert_script_run('sysctl -w net.ipv6.conf.all.disable_ipv6=0');
}

# ----------------------------- CLIENT --------------------------------

sub test_winbind() {
    # Start winbind for wbinfo tests
    systemctl('enable --now winbind');

    # Verify users and groups from AD via winbind.
    my @wbinfo_tests = (
        'wbinfo -D ' . DOMAIN,
        'wbinfo -tP',
        "wbinfo -u | grep 'testuser'",
        "wbinfo -g",
        "wbinfo -i testuser\@" . REALM
    );
    assert_script_run($_, timeout => 30) for @wbinfo_tests;
}

sub test_adcli($client_hostname) {
    my $server_fqdn = 'server.' . lc(REALM);
    assert_script_run('echo ' . PASSWORD . ' | adcli join --verbose --domain ' . REALM . ' -S ' . $server_fqdn . ' -U Administrator --stdin-password');

    record_info('adcli info', script_output("adcli info -D " . REALM . " -S $server_fqdn -v"));

    # adcli update tests (password rotation)
    script_retry('adcli update --verbose --computer-password-lifetime=0 --domain ' . REALM, retry => 3, delay => 60);
    # restore password with samba data
    script_retry('adcli update --verbose --computer-password-lifetime=0 --domain ' . REALM . ' --add-samba-data', retry => 3, delay => 60);

    # Leave using adcli (delete computer account)
    assert_script_run('echo ' . PASSWORD . ' | adcli delete-computer --domain ' . REALM . ' -U Administrator --stdin-password ' . $client_hostname);
}

# Randomize hostname to prevent conflicts with other clients
sub randomize_hostname() {
    my $hostname = 'client-' . random_string(length => 8);
    assert_script_run("hostnamectl set-hostname '$hostname'");
    assert_script_run("echo \"127.0.0.1 $hostname\" >> /etc/hosts");
    return $hostname;
}

sub verify_dns_records($dns_server) {
    my @srv_records = qw(_ldap._tcp _kerberos._tcp _kerberos._udp _kpasswd._udp);
    foreach my $srv (@srv_records) {
        script_retry("dig \@$dns_server +short -t SRV ${srv}." . REALM, retry => 3, timeout => 10, die => 1, fail_message => "failed to resolve $srv SRV record");
    }
}

sub run_client() {
    diag 'Waiting for barriers creation';
    # before using barriers, we need to wait until the server has created the barriers
    mutex_wait 'SAMBA_DC_BARRIERS_READY';
    # after this mutex unlocks, we can use the barriers to wait for the server
    # in the meantime, install necessary packages
    zypper_call('in samba-client krb5-client samba-winbind bind-utils adcli cyrus-sasl-gssapi');
    disable_ipv6();
    barrier_wait('SAMBA_DC_SETUP');

    my $client_hostname = randomize_hostname();

    my $server_ip = script_output(q{getent hosts server | head -n1 | awk '{print $1}'});
    my $interface = script_output("nmcli -t -f NAME c | grep -v '^lo' | head -n1");
    assert_script_run("nmcli con mod \"$interface\" ipv4.dns \"$server_ip\" ipv4.ignore-auto-dns yes");
    assert_script_run("nmcli con up \"$interface\"");

    # Ensure DNS name resolution works for the AD host
    script_retry("ping -c 2 $server_ip", retry => 3, timeout => 60, die => 1, fail_message => "$server_ip is unreachable");

    verify_dns_records($server_ip);

    my @smb_conf_setup = (
        'echo "[global]" > /etc/samba/smb.conf',
        'echo "   workgroup = ' . DOMAIN . '" >> /etc/samba/smb.conf',
        'echo "   realm = ' . REALM . '" >> /etc/samba/smb.conf',
        'echo "   security = ads" >> /etc/samba/smb.conf',
        'echo "   idmap config * : backend = tdb" >> /etc/samba/smb.conf',
        'echo "   idmap config * : range = 3000-7999" >> /etc/samba/smb.conf'
    );
    assert_script_run($_) for @smb_conf_setup;
    assert_script_run('net ads join -U Administrator%' . PASSWORD);
    assert_script_run('net ads testjoin');
    assert_script_run('smbclient -L //server -I ' . $server_ip . ' -U testuser%' . PASSWORD);

    # Verify Kerberos
    validate_script_output('echo ' . PASSWORD . ' | kinit -V Administrator@' . REALM, sub { /Authenticated to Kerberos/ });

    test_winbind();

    # undo join (== leave) the domain
    assert_script_run('net ads leave -U Administrator%' . PASSWORD);

    # rejoin the domain, now using adcli
    test_adcli($client_hostname);

    enable_ipv6();
    # signal that the client is finished
    barrier_wait('SAMBA_DC_FINISHED');
}

# ---------------------------- SERVER -------------------------------

# Configure DNS settings for the server
sub configure_server_resolver() {
    my $dns_forwarder = script_output(q{awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf});
    assert_script_run("sed -i '/\\[global\\]/a dns forwarder = $dns_forwarder' /etc/samba/smb.conf");
    # Configure DNS to point to localhost using nmcli
    my $interface = script_output("nmcli -t -f NAME c | grep -v '^lo' | head -n1");
    assert_script_run("nmcli con mod \"$interface\" ipv4.dns \"127.0.0.1\" ipv4.ignore-auto-dns yes");
    assert_script_run("nmcli con mod \"$interface\" ipv4.dns-search " . REALM);
    assert_script_run("nmcli con up \"$interface\"");
}

# Start samba services
sub validate_samba_services() {
    systemctl('enable --now samba-ad-dc.service');
    systemctl('status samba-ad-dc.service');
    verify_dns_records('localhost');
    # internal checks that samba is running as expected
    validate_script_output('samba-tool domain level show', sub { /Forest function level:.*2008 R2/ }, 60);
    validate_script_output('echo ' . PASSWORD . ' | kinit -V Administrator', sub { /Authenticated to Kerberos/ });
    # use klist to verify that the ticket was obtained
    validate_script_output('klist', sub { /Default principal: Administrator@${\(REALM)}/ });
}

sub setup_samba_server() {
    zypper_call('in samba-ad-dc samba-ad-dc-libs krb5-client');
    # Setup samba as AD DC
    assert_script_run('mv /etc/samba/smb.conf /etc/samba/smb.conf.orig');
    assert_script_run('samba-tool domain provision --domain ' . DOMAIN . ' --realm=' . REALM . ' --adminpass=' . PASSWORD . ' --server-role=dc --use-rfc2307 --dns-backend=SAMBA_INTERNAL');
    assert_script_run 'cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf';
    assert_script_run q{sed -i '/^\[libdefaults\]/a default_ccache_name = FILE:/tmp/krb5cc_%{uid}' /etc/krb5.conf};
}

sub run_server() {
    barrier_create('SAMBA_DC_SETUP', 2);
    barrier_create('SAMBA_DC_FINISHED', 2);
    # Create a final mutex to signal all jobs that barriers are ready to use
    # It must be used with mutex_wait() before any barrier_wait() calls in the child jobs
    mutex_create('SAMBA_DC_BARRIERS_READY');
    # Install samba and necessary packages
    disable_ipv6();
    setup_samba_server();
    configure_server_resolver();
    validate_samba_services();
    # add a test user
    assert_script_run('samba-tool user create testuser ' . PASSWORD);
    # Setup done. Signal client to proceed with its tests
    barrier_wait('SAMBA_DC_SETUP');
    # Wait for client tests to finish
    barrier_wait('SAMBA_DC_FINISHED');
    enable_ipv6();
}

1;
