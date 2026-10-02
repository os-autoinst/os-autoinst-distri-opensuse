# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Minimal Kerberos realm helpers for kernel multi-machine tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::krb5;

use base Exporter;
use Exporter;

use strict;
use warnings;
use List::Util 'uniq';
use testapi;
use utils qw(systemctl write_sut_file);
use version_utils 'is_sle';

our @EXPORT_OK = qw(
  krb5_enctype
  setup_krb5_conf
  setup_krb5_kdc
  add_principal
  add_host_principals
);

# Defaults for the realm settings that callers can override
my %defaults = (
    realm => 'KERNEL-QE.TEST',
    admin => 'root/admin',
    admin_pass => 'Admin_pass',
    db_pass => 'DB_phrase',
    enctype => undef,    # krb5_enctype() for the product under test
);
my $kdc_dir = '/var/lib/kerberos/krb5kdc';
my $keytab = '/etc/krb5.keytab';

=head1 SYNOPSIS

Set up a small Kerberos realm for kernel tests that need Kerberos, for
example NFS with C<sec=krb5>. One node runs the KDC and C<kadmind>, all
nodes use the same C<krb5.conf> and add their own service principals.

=head2 Realm settings

All functions accept these optional named arguments. Each one defaults to
a fixed test value:

=over

=item C<realm> - realm name, defaults to C<KERNEL-QE.TEST>

=item C<admin> - admin principal, defaults to C<root/admin>

=item C<admin_pass> - password of the admin principal, defaults to C<Admin_pass>

=item C<db_pass> - master password of the KDC database, defaults to C<DB_phrase>

=item C<enctype> - the only encryption type of the realm, defaults to C<krb5_enctype()>

=back

A function uses only the settings that it needs. The KDC and all other
nodes must use the same values: if a caller overrides a setting on the KDC,
it must pass the same value on the other nodes too.

=cut

sub _settings {
    my (%args) = @_;
    my $s = {%defaults, map { $_ => $args{$_} } grep { exists $defaults{$_} } keys %args};
    $s->{enctype} //= krb5_enctype();
    return $s;
}

=head2 krb5_enctype

  my $enctype = krb5_enctype();

Return the encryption type to use for the realm. SLE older than 15-SP6
does not support C<aes256-cts-hmac-sha384-192> in the kernel GSS code,
thus use C<aes256-cts-hmac-sha1-96> there.

=cut

sub krb5_enctype {
    return is_sle('<15-SP6') ? 'aes256-cts-hmac-sha1-96' : 'aes256-cts-hmac-sha384-192';
}

=head2 setup_krb5_conf

  setup_krb5_conf($kdc [, realm => $realm, enctype => $enctype, libdefaults => {$key => $value}, includedir => $dir]);

Write C<krb5.conf> for the test realm with C<kdc> as KDC and admin server.
C<kdc> can include a port, for example C<127.0.0.1:88>.

Hostname canonicalization is disabled, thus principals use the host names
exactly as the tests use them. The acceptor accepts each key in its keytab,
independent of the host name that the client used.

C<libdefaults> adds keys to the C<[libdefaults]> section or replaces the
default values. A key with the value C<undef> is removed.

C<includedir> adds an C<includedir> directive in front of the sections.
It defaults to C</etc/krb5.conf.d> if that directory exists, the same as
the vendor configuration. Then the system crypto policy, for example FIPS
mode, applies to the test realm too. The included files are read first and
for a key that occurs more than once, the first value is used. Thus the
included files take precedence, for example the C<permitted_enctypes> of
the crypto policy. Set C<includedir> to C<undef> to write a configuration
that contains only the values of this function.

Write the test configuration to C</etc/krb5.conf>. This file takes
precedence over the vendor configuration in C</usr/etc/krb5.conf>.

Call it first, after the Kerberos packages are installed: it also makes the
MIT Kerberos tools available in the current shell. SLE 15 installs them to
C</usr/lib/mit/bin> and C</usr/lib/mit/sbin> and adds these to C<PATH> only
in new login shells, through C</etc/profile.d/krb5.sh>. Products without that
file have the tools in C<PATH> already.

=cut

sub setup_krb5_conf {
    my ($kdc, %args) = @_;

    # SLE 15: put /usr/lib/mit/{bin,sbin} into PATH of this shell
    script_run('if [ -f /etc/profile.d/krb5.sh ]; then . /etc/profile.d/krb5.sh; fi');
    my $s = _settings(%args);
    my $realm = $s->{realm};
    my %libdefaults = (
        default_realm => $realm,
        dns_lookup_kdc => 'false',
        dns_lookup_realm => 'false',
        dns_canonicalize_hostname => 'false',
        rdns => 'false',
        ignore_acceptor_hostname => 'true',
        default_tgs_enctypes => $s->{enctype},
        default_tkt_enctypes => $s->{enctype},
        permitted_enctypes => $s->{enctype},
        %{$args{libdefaults} // {}},
    );
    my $libdefaults = join('', map { "    $_ = $libdefaults{$_}\n" } grep { defined $libdefaults{$_} } sort keys %libdefaults);
    my $includedir = exists $args{includedir} ? $args{includedir} : (script_run('test -d /etc/krb5.conf.d') == 0 ? '/etc/krb5.conf.d' : undef);
    $includedir = defined $includedir ? "includedir $includedir\n\n" : '';
    my $conf = '/etc/krb5.conf';

    write_sut_file($conf, <<END);
$includedir\[libdefaults]
$libdefaults
[realms]
    $realm = {
        kdc = $kdc
        admin_server = $kdc
    }

[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
END
    record_info('krb5.conf', script_output("cat $conf"));
}

=head2 setup_krb5_kdc

  setup_krb5_kdc([realm => $realm, enctype => $enctype, admin => $admin, admin_pass => $pass, db_pass => $pass]);

Create the realm database on this node, add the admin principal and start
C<krb5kdc> and C<kadmind>. Call C<setup_krb5_conf()> with the same realm
before.

=cut

sub setup_krb5_kdc {
    my (%args) = @_;
    my $s = _settings(%args);
    my $realm = $s->{realm};
    my $enctype = $s->{enctype};

    write_sut_file("$kdc_dir/kdc.conf", <<END);
[kdcdefaults]
    kdc_ports = 88

[realms]
    $realm = {
        database_name = $kdc_dir/principal
        admin_keytab = FILE:$kdc_dir/kadm5.keytab
        acl_file = $kdc_dir/kadm5.acl
        key_stash_file = $kdc_dir/.k5.$realm
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = $enctype
        supported_enctypes = $enctype:normal
    }
END
    write_sut_file("$kdc_dir/kadm5.acl", "$s->{admin}\@$realm *\n");

    assert_script_run("kdb5_util create -r $realm -s -P $s->{db_pass}", timeout => 300);
    assert_script_run("kadmin.local -q 'addprinc -pw $s->{admin_pass} $s->{admin}'");
    systemctl('enable --now krb5kdc');
    systemctl('enable --now kadmind');
    record_info('KDC', script_output('kadmin.local -q listprincs'));
}

=head2 add_principal

  add_principal($name [, keytab => 1, remote => 1, admin => $admin, admin_pass => $pass]);

Add the principal C<name> with a random key to the KDC, for example the
user principal C<fsgqa>. Give C<name> without realm, the principal is in
the default realm of C<krb5.conf>.

Use C<keytab> to also add the key to C</etc/krb5.keytab>.

Use C<remote> on nodes other than the KDC: then C<kadmin> connects to
C<kadmind> as the admin principal, else C<kadmin.local> is used.

The function makes sure that the principal exists, because C<kadmin -q>
does not always report a failed query in its exit status.

=cut

sub add_principal {
    my ($name, %args) = @_;
    my $s = _settings(%args);
    my $kadmin = $args{remote} ? "kadmin -p $s->{admin} -w $s->{admin_pass}" : 'kadmin.local';

    assert_script_run("$kadmin -q 'addprinc -randkey $name'");
    assert_script_run("$kadmin -q 'getprinc $name' | grep -q '^Principal: $name\@'");
    return unless $args{keytab};
    assert_script_run("$kadmin -q 'ktadd -k $keytab $name'");
    assert_script_run("klist -k $keytab | grep -qF ' $name\@'");
}

=head2 add_host_principals

  add_host_principals($service [, remote => 1, admin => $admin, admin_pass => $pass]);

Add the principal C<service>/I<host> to the KDC and its key to
C</etc/krb5.keytab>, see C<add_principal()>. I<host> is the short host
name and, if different, the fully qualified host name, thus the key
matches both names.

=cut

sub add_host_principals {
    my ($service, %args) = @_;
    my @hosts = uniq(split(/\s+/, script_output('hostname; hostname -f 2>/dev/null; true')));

    add_principal("$service/$_", %args, keytab => 1) foreach (@hosts);
    record_info('keytab', script_output("klist -ke $keytab"));
}

1;
