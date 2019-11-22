#! /usr/bin/perl -w

use strict;
use Getopt::Long;

my $realm        = "";
my $hostname     = "";
my $domain       = "";
my $adminpw      = "";
my $vadminpw     = "";
my $help         = "";
my $noinstall    = 0;
my $noy2kc_c     = 0;
my $nosshd_c     = 0;
my $nossh_c      = 0;
my $nokadmin     = 0;
my $nomasterkdc  = 0;
my $notesteruser = 0;
my $ldapdb       = 0;

my $ldapadminpw  = "";
my $vldapadminpw = "";
my $basedn       = "";
my $rootdnprefix = "cn=Administrator,";


my $db = "/var/lib/kerberos/krb5kdc/principal";

my $yast_inst_pack = "krb5 krb5-server krb5-client krb5-doc pam_krb5";

##########################################################################
## The kadmin commands
##
## 1. Value     => kadmin command
## 2-nth. Value => input for the command
##
##########################################################################
#                     command                                1.input   2.input ...
my $kadmin_cmds = [
    ['addprinc susetest\@$realm',       "system", "system"],
    ['addprinc susetest/admin\@$realm', "system", "system"],
    ['addprinc tester\@$realm',         "system", "system"],
    ['addprinc -randkey host/hostname.domain.de'],
    ['getprincs'],
    ['listpols'],
    ['addpol -maxlife \"60 days\" -minlife \"10 days\" -minlength 7 myPolicy'],
    ['listpols'],
    ['getpol myPolicy'],
    ['modpol -minclasses 2 myPolicy'],
    ['getpol myPolicy'],
    ['getprivs'],
    ['ktadd -k /tmp/test.keytab host/hostname.domain.de'],
    ['ktremove -k /tmp/test.keytab host/hostname.domain.de'],
    ['cpw tester', "1234wert", "1234wert"],
    ['modprinc -policy myPolicy tester'],
    ['getprinc tester'],
    ['cpw tester', "w", "w"],
    ['delprinc mcalmer', 'yes'],
    ['delpol myPolicy',  'yes'],
    ['listpols'],
    ['modprinc -clearpolicy tester'],
    ['getprinc tester'],
    ['delpol myPolicy', 'yes'],
    ['listpols']
];

my $result = GetOptions("realm|r=s" => \$realm,
    "ldapdb"       => \$ldapdb,
    "nomasterkdc"  => \$nomasterkdc,
    "noinstall|ni" => \$noinstall,
    "noy2kc"       => \$noy2kc_c,
    "nosshd"       => \$nosshd_c,
    "nossh"        => \$nossh_c,
    "nokadmin"     => \$nokadmin,
    "notesteruser" => \$notesteruser,
    "help|h"       => \$help
);


if ($help || !defined $realm || $realm eq "")
{
    print "usage: setup-kerberos-server.pl --realm <REALM> [<other options>] [--help]\n";
    print " other options are:\n";
    print "       --ldapdb            use ldap as db backend(setup a local ldap server)\n";
    print "       --noinstall -ni     do not install required packages\n";
    print "       --nomasterkdc       do not configure a master KDC\n";
    print "       --noy2kc            do not configure yast2 kerberos-client\n";
    print "       --nosshd            do not configure sshd\n";
    print "       --nossh             do not configure ssh\n";
    print "       --nokadmin          do not execute extra kadmin commands\n";
    print "       --notesteruser         do not create a user 'tester'\n";
    exit 0;
}

open(HOSTNAME, "/bin/hostname|") or die "Can not execute hostname: $!";
chomp($hostname = <HOSTNAME>);
close(HOSTNAME);

if (!defined $hostname || $hostname eq "")
{
    print STDERR "Can not get hostname\n";
    exit 1;
}
else
{
    print STDOUT "hostname=$hostname\n";
}

open(DOMAIN, "/bin/hostname -d|") or die "Can not execute hostname: $!";
chomp($domain = <DOMAIN>);
close(DOMAIN);

if (!defined $domain || $domain eq "")
{
    print STDERR "Can not get domain\n";
    exit 1;
}
else
{
    print STDOUT "domain=$domain\n";
}


if ($ldapdb)
{
    my @dn = split('\.', $domain);
    $basedn = "dc=" . join(",dc=", @dn);

    print STDOUT "BaseDN=$basedn\n";

    $yast_inst_pack .= " openldap2 openldap2-client";
}


sub ask_adminpw
{
    print "Please enter the administrator password:";
    system("stty -echo") == 0 or die "Can not disable echo mode: $!";
    $adminpw = "123456";
    print "\nPlease re-enter the administrator password:";
    $vadminpw = "123456";
    system("stty echo");
    print "\n";

    if ($vadminpw ne $adminpw)
    {
        print STDERR "The passwords does not match.";
        exit 1;
    }

    if ($ldapdb)
    {
        print "Please enter the LDAP administrator password:";
        system("stty -echo") == 0 or die "Can not disable echo mode: $!";
        chomp($ldapadminpw = <STDIN>);
        print "\nPlease re-enter the LDAP administrator password:";
        chomp($vldapadminpw = <STDIN>);
        system("stty echo");
        print "\n";

        if ($vldapadminpw ne $ldapadminpw)
        {
            print STDERR "The passwords does not match.";
            exit 1;
        }
    }
}


##############################################################################
## cleanup
##############################################################################
sub cleanup_kdc()
{

    system("/usr/bin/systemctl stop kadmind") == 0
      or die "Can not stop kadmind: $!";

    system("/usr/bin/systemctl stop krb5kdc") == 0
      or die "Can not stop krb5kdc: $!";

    if (-e $db && !$ldapdb)
    {
        print "Database '$db' exists; I Remove it\n";

        system("/usr/lib/mit/sbin/kdb5_util destroy") == 0
          or die "Can not execute kdb5_util: $!";
    }
    if ($ldapdb)
    {
        my $dirs = `grep ^directory /etc/openldap/slapd.conf`;
        if ($? == 0)
        {
            my $removeOK = "no";

            print "Remove complete LDAP service. OK?[yes|no]\n";
            chomp($removeOK = <STDIN>);

            if ($removeOK eq "yes")
            {
                my @ldapdirs = split('\n', $dirs);

                system("/usr/bin/systemctl stop ldap") == 0
                  or die "Can not stop ldap: $!";

                foreach my $d (@ldapdirs)
                {
                    if ($d =~ /^directory\s+(.+)\s*$/ && defined $1 && $1 ne "")
                    {
                        system("rm /$1/*") == 0
                          or die "Can not remove content of $d: $!";
                    }
                }
            }
            else
            {
                print "Abort\n";
                exit 1;
            }
        }
    }

    if (-e '/etc/krb5.keytab')
    {
        unlink('/etc/krb5.keytab') == 1
          or die("Can not delete krb5.keytab: $!");
    }
}

##############################################################################
## install packages
##############################################################################
sub install
{
    system("yast2 -i $yast_inst_pack") == 0 or die "Can not install required packages: $!";
}


##############################################################################
## setup ldap
##############################################################################
sub setup_ldap
{
    print STDERR "setup_ldap\n";
    open(SLAPDCONF, "> /etc/openldap/slapd.conf")
      or die("Can not write slapd.conf: $!");

    print SLAPDCONF <<EOF
#
# See slapd.conf(5) for details on configuration options.
# This file should NOT be world readable.
#
include         /etc/openldap/schema/core.schema
include         /etc/openldap/schema/cosine.schema
include         /etc/openldap/schema/inetorgperson.schema
include         /etc/openldap/schema/rfc2307bis.schema
include         /usr/share/doc/packages/krb5/kerberos.schema
include         /etc/openldap/schema/yast.schema

# Define global ACLs to disable default read access.

# Do not enable referrals until AFTER you have a working directory
# service AND an understanding of referrals.
#referral       ldap://root.openldap.org

pidfile         /var/run/slapd/slapd.pid
argsfile        /var/run/slapd/slapd.args

# Load dynamic backend modules:
modulepath      /usr/lib/openldap/modules
# moduleload    back_ldap.la
# moduleload    back_meta.la
# moduleload    back_monitor.la
# moduleload    back_perl.la

# Sample security restrictions
#       Require integrity protection (prevent hijacking)
#       Require 112-bit (3DES or better) encryption for updates
#       Require 63-bit encryption for simple bind
# security ssf=1 update_ssf=112 simple_bind=64

# Sample access control policy:
#       Root DSE: allow anyone to read it
#       Subschema (sub)entry DSE: allow anyone to read it
#       Other DSEs:
#               Allow self write access to user password
#               Allow anonymous users to authenticate
#               Allow read access to everything else
#       Directives needed to implement policy:
access to dn.base=""
        by * read

access to dn.base="cn=Subschema"
        by * read

access to attrs=userPassword,userPKCS12
        by self write
        by * auth

access to attrs=shadowLastChange
        by self write
        by * read

access to *
        by * read

# if no access controls are present, the default policy
# allows anyone and everyone to read anything but restricts
# updates to rootdn.  (e.g., "access to * by * read")
#
# rootdn can always read and write EVERYTHING!

loglevel 256

#######################################################################
# BDB database definitions
#######################################################################

EOF
      ;

    print STDERR "configuring LDAPI support\n";
    open(OPL, "< /etc/sysconfig/openldap")
      or die("Can not read etc/sysconfig/openldap: $!");

    my @newconf = ();
    while (my $line = <OPL>)
    {
        if ($line =~ /^OPENLDAP_START_LDAPI/)
        {
            push @newconf, "OPENLDAP_START_LDAPI=\"yes\"\n";
        }
        else
        {
            push @newconf, $line;
        }
    }
    close OPL;

    open(OPL, "> /etc/sysconfig/openldap")
      or die("Can not write etc/sysconfig/openldap: $!");
    print OPL @newconf;
    close OPL;


    print STDERR "add the database\n";

    system("yast2 ldap-server addDatabase basedn='$basedn' rootdn='$rootdnprefix$basedn' password='$ldapadminpw' dbdir='/var/lib/ldap'") == 0 or die "Can setup ldap server: $!";

    print STDERR "configuring ldap-client\n";

    system("yast2 ldap-client configure server='$hostname.$domain' base='$basedn' createconfig ldappw='$ldapadminpw'") == 0 or die "Can setup ldap client: $!";

}


##############################################################################
## writing kdc.conf
##############################################################################
sub write_kdcconf
{
    print STDERR "write_kdcconf\n";
    open(KDCCONF, "> /var/lib/kerberos/krb5kdc/kdc.conf")
      or die("Can not write kdc.conf: $!");

    if (!$ldapdb)
    {
        print KDCCONF <<EOF
[kdcdefaults]
        kdc_ports = 750,88

[realms]
        $realm = {
                database_name = $db
                admin_keytab = FILE:/var/lib/kerberos/krb5kdc/kadm5.keytab
                acl_file = /var/lib/kerberos/krb5kdc/kadm5.acl
                dict_file = /var/lib/kerberos/krb5kdc/kadm5.dict
                key_stash_file = /var/lib/kerberos/krb5kdc/.k5.$realm
                kdc_ports = 750,88
                max_life = 10h 0m 0s
                max_renewable_life = 7d 0h 0m 0s
        }

EOF
          ;
    }
    else
    {
        print KDCCONF <<EOF
[kdcdefaults]
        kdc_ports = 750,88

[realms]
        $realm = {
                admin_keytab = FILE:/var/lib/kerberos/krb5kdc/kadm5.keytab
                acl_file = /var/lib/kerberos/krb5kdc/kadm5.acl
                key_stash_file = /var/lib/kerberos/krb5kdc/.k5.$realm
                kdc_ports = 750,88
                max_life = 10h 0m 0s
                max_renewable_life = 7d 0h 0m 0s
        }

EOF
          ;
    }
    close(KDCCONF);
}

##############################################################################
## writing krb5.conf
##############################################################################
sub write_krb5conf
{
    print STDERR "write_krb5conf\n";
    open(KRB5CONF, "> /etc/krb5.conf")
      or die("Can not write krb5.conf: $!");

    if (!$ldapdb)
    {

        print KRB5CONF <<EOF

[libdefaults]
        default_realm = $realm
        clockskew = 300

[realms]
  $realm = {
        kdc = $hostname.$domain
        admin_server = $hostname.$domain
        default_domain = $domain
}

[logging]
        kdc = FILE:/var/log/krb5/krb5kdc.log
        admin_server = FILE:/var/log/krb5/kadmind.log
        default = SYSLOG:NOTICE:DAEMON

[domain_realm]
        .$domain = $realm
        $domain = $realm

[appdefaults]
        pam = {
                ticket_lifetime = 1d
                renew_lifetime = 1d
                forwardable = true
                proxiable = false
                retain_after_close = false
                minimum_uid = 1
                try_first_pass = true
                debug = true
        }

EOF
          ;
    }
    else
    {
        print KRB5CONF <<EOF

[libdefaults]
        default_realm = $realm
        clockskew = 300

[realms]
  $realm = {
        kdc = $hostname.$domain
        admin_server = $hostname.$domain
        default_domain = $domain
        database_module = ldap
}

[logging]
        kdc = FILE:/var/log/krb5/krb5kdc.log
        admin_server = FILE:/var/log/krb5/kadmind.log
        default = SYSLOG:NOTICE:DAEMON

[domain_realm]
        .$domain = $realm
        $domain = $realm

[dbmodules]
        ldap = {
                db_library = kldap
                ldap_kerberos_container_dn = cn=krbcontainer,$basedn
                ldap_servers = ldapi:///
                ldap_kdc_dn = "$rootdnprefix$basedn"
                ldap_kadmind_dn = "$rootdnprefix$basedn"
                ldap_service_password_file = /etc/openldap/ldap-pw
        }


[appdefaults]
        pam = {
                ticket_lifetime = 1d
                renew_lifetime = 1d
                forwardable = true
                proxiable = false
                retain_after_close = false
                minimum_uid = 1
                try_first_pass = true
                debug = true
        }

EOF
          ;

    }

    close(KRB5CONF);
}

##############################################################################
## setting up kdc
##############################################################################
sub setup_kdc
{
    print STDERR "setup_kdc\n";
    if (!$ldapdb)
    {
        open(KDB5CREATE, "|/usr/lib/mit/sbin/kdb5_util create -r $realm -s")
          or die "Can not execute kdb5_util: $!";

        print KDB5CREATE "$adminpw\n";
        print KDB5CREATE "$adminpw\n";

        close(KDB5CREATE);
    }
    else
    {
        my $cmd  = "/usr/lib/mit/sbin/kdb5_ldap_util";
        my @args = ();

        push @args, "-D",     "$rootdnprefix$basedn", "-H",                "ldapi:///";
        push @args, "create", "-subtrees",            "ou=people,$basedn", "-sscope", "SUB";
        push @args, "-k",     "des3-cbc-sha1",        "-sf",               "/var/lib/kerberos/krb5kdc/.k5.$realm", "-r", "$realm";

        open(KDB5CREATE, "|$cmd " . join(" ", @args))
          or die "Can not execute kdb5_ldap_util: $!";

        print KDB5CREATE "$ldapadminpw\n";
        print KDB5CREATE "$adminpw\n";
        print KDB5CREATE "$adminpw\n";

        close(KDB5CREATE);

        @args = ();

        push @args, "stashsrvpw", "-f", "/etc/openldap/ldap-pw", "$rootdnprefix$basedn";

        open(KDB5CREATE, "|$cmd " . join(" ", @args))
          or die "Can not execute kdb5_ldap_util: $!";

        print KDB5CREATE "$ldapadminpw\n";
        print KDB5CREATE "$ldapadminpw\n";

        close(KDB5CREATE);
    }

    ##############################################################################
    ## writing kadm5.acl
    ##############################################################################

    open(KADMCONF, "> /var/lib/kerberos/krb5kdc/kadm5.acl")
      or die("Can not write kadm5.acl: $!");

    print KADMCONF <<EOF
###############################################################################
#Kerberos_principal      permissions     [target_principal]      [restrictions]
###############################################################################
#
*/admin\@$realm  *

EOF
      ;

    close(KADMCONF);


    ##############################################################################
    ## some kadmin magics
    ##############################################################################

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'addprinc admin/admin\@$realm'")
      or die "Can not execute kadmin.local: $!";
    print KADMIN "$adminpw\n";
    print KADMIN "$adminpw\n";

    close(KADMIN);

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'ktadd -k /var/lib/kerberos/krb5kdc/kadm5.keytab kadmin/admin kadmin/changepw'")
      or die "Can not execute kadmin.local: $!";

    close(KADMIN);

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'addprinc -randkey host/$hostname.$domain'")
      or die "Can not execute kadmin.local: $!";

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'addprinc -randkey host/$hostname'")
      or die "Can not execute kadmin.local: $!";

    close(KADMIN);

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'ktadd host/$hostname.$domain'")
      or die "Can not execute kadmin.local: $!";

    open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q 'ktadd host/$hostname'")
      or die "Can not execute kadmin.local: $!";

    close(KADMIN);

    ##############################################################################
    ## starting services
    ##############################################################################

    system("/usr/bin/systemctl start kadmind") == 0
      or die "Can not start kadmind: $!";

    system("/usr/bin/systemctl start krb5kdc") == 0
      or die "Can not start krb5kdc: $!";
}

###############################################################################
# creating user tester
###############################################################################

sub usertester
{
    if (system('id tester') != 0)
    {
        system('useradd -m tester') == 0
          or die "Can not create user 'tester': $!";
    }
}

sub kadmin
{
    foreach my $cmd_set (@$kadmin_cmds)
    {
        my $cmd  = $cmd_set->[0];
        my $kcmd = "";
        eval "\$kcmd = \"$cmd\"";
        print "################ execute:$kcmd ###################\n";
        #open(KADMIN, "|/usr/lib/mit/sbin/kadmin -p admin/admin\@$realm -q '$kcmd'")
        open(KADMIN, "|/usr/lib/mit/sbin/kadmin.local -q '$kcmd'")
          or die "Can not execute kadmin.local: $!";

        #print KADMIN "$adminpw\n";

        for (my $i = 1; $i < @$cmd_set; $i++)
        {
            print KADMIN $cmd_set->[$i] . "\n";
        }

        close(KADMIN);
        print "\n\n STATUS: $?\n";
        print "##################################################\n";
    }
}


##############################################################################
## configure yast2-kerberos-client
##############################################################################
sub config_y2kc
{
    system("yast kerberos-client configure kdc='$hostname.$domain' domain='$domain' realm='$realm' verbose") == 0
      or die "Can not execute yast2 kerberos-client: $!";

    system("yast kerberos-client pam enable") == 0
      or die "Can not execute yast2 kerberos-client: $!";
}


##############################################################################
## configure sshd
##############################################################################
sub config_sshd
{
    open(SSHD, "</etc/ssh/sshd_config")
      or die "Can not open file: $!";

    my @sshd = <SSHD>;

    close(SSHD);

    my @new_sshd = ();

    my $found_auth  = 0;
    my $found_clean = 0;

    foreach my $line (@sshd)
    {
        if (!$found_auth && $line =~ /GSSAPIAuthentication/)
        {
            push(@new_sshd, "GSSAPIAuthentication yes\n");
            $found_auth = 1;
            next;
        }
        elsif (!$found_clean && $line =~ /GSSAPICleanupCredentials/)
        {
            push(@new_sshd, "GSSAPICleanupCredentials yes\n");
            $found_clean = 1;
            next;
        }
        push(@new_sshd, $line);
    }

    if (!$found_auth)
    {
        push(@new_sshd, "GSSAPIAuthentication yes\n");
    }
    if (!$found_clean)
    {
        push(@new_sshd, "GSSAPICleanupCredentials yes\n");
    }

    open(SSHD, ">/etc/ssh/sshd_config")
      or die "Can not open file: $!";

    print SSHD @new_sshd;

    close(SSHD);

    system("/usr/bin/systemctl restart sshd") == 0
      or die "Can not restart sshd: $!";
}

##############################################################################
## configure ssh
##############################################################################
sub config_ssh
{
    open(SSH, "</etc/ssh/ssh_config")
      or die "Can not open file: $!";

    my @ssh = <SSH>;

    close(SSH);

    my @new_ssh = ();

    my $found_auth = 0;
    my $found_cred = 0;

    foreach my $line (@ssh)
    {
        if (!$found_auth && $line =~ /GSSAPIAuthentication/)
        {
            push(@new_ssh, "GSSAPIAuthentication yes\n");
            $found_auth = 1;
            next;
        }
        elsif (!$found_cred && $line =~ /GSSAPIDelegateCredentials/)
        {
            push(@new_ssh, "GSSAPIDelegateCredentials yes\n");
            $found_cred = 1;
            next;
        }
        push(@new_ssh, $line);
    }

    if (!$found_auth)
    {
        push(@new_ssh, "GSSAPIAuthentication yes\n");
    }
    if (!$found_cred)
    {
        push(@new_ssh, "GSSAPIDelegateCredentials yes\n");
    }

    open(SSH, ">/etc/ssh/ssh_config")
      or die "Can not open file: $!";

    print SSH @new_ssh;

    close(SSH);
}


if (!$noinstall)
{
    print "###################################################\n";
    print "## install packages\n";
    print "###################################################\n";
    install();
}


if (!$nomasterkdc)
{
    print "###################################################\n";
    print "## configure master KDC\n";
    print "###################################################\n";
    ask_adminpw();
    cleanup_kdc();

    if ($ldapdb)
    {
        setup_ldap();
    }

    write_kdcconf();

    if (defined $noy2kc_c || $ldapdb)
    {
        write_krb5conf();
    }
    else
    {
        config_y2kc();
    }

    setup_kdc();
}

if (!$notesteruser)
{
    print "###################################################\n";
    print "## creating user 'tester'\n";
    print "###################################################\n";
    usertester();
}

if (!$nokadmin)
{
    print "###################################################\n";
    print "## execute extra kadmin commands\n";
    print "###################################################\n";
    kadmin();
}

if (not defined $noy2kc_c)
{
    print "###################################################\n";
    print "## configure yast2 kerberos-client\n";
    print "###################################################\n";
    config_y2kc();
}

if (!$nosshd_c)
{
    print "###################################################\n";
    print "## configure sshd\n";
    print "###################################################\n";
    config_sshd();
}

if (!$nossh_c)
{
    print "###################################################\n";
    print "## configure ssh\n";
    print "###################################################\n";
    config_ssh();
}

if (!$nosshd_c && !$notesteruser)
{
    print "###################################################\n";
    print "## add tester user to /root/.k5login \n";
    print "###################################################\n";
    open(K5LOGIN, "> /root/.k5login")
      or die "Cannot open file: $!";

    print K5LOGIN "tester@" . $realm . "\n";

    close K5LOGIN;
}


exit 0;
