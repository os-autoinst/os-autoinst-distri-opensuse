# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test preparing services to use with multimachine scenarios.
#  At least confiugre:
#   - http - A basic http support with apache2
#   - ldap - A simple openladp with users.
#   - ftp  - simple ftp server
#  Use on test variables settings: SUPPORT_SERVER_ROLES=http,ldap
#  The firewall was disable and network configuration used was provide by  tests/network/setup_multimachine.pm
#  This script was based from tests/support_server/setup.pm, but not use serial
#  console or neddles. This is to facilites to run on all SLES/OPensuse versions.
#
# Maintainer: Marcelo Martins <mmartins@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(systemctl zypper_call);

my $http_server_set = 0;
my $ldap_server_set = 0;
my $ftp_server_set  = 0;
my $setup_script;

sub setup_http_server {
    #install and configure simple apache2 if $http_server_set;
    zypper_call('in  apache2');
    systemctl('stop apache2');
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/http/apache2  >/etc/sysconfig/apache";
    systemctl('start apache2');
    $http_server_set = 1;
}

sub setup_ldap_server {
    #install and configure basic openldap2 if $ldap_server_set
    zypper_call('in openldap2');
    systemctl('stop slapd');
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/ldap/slapd.conf > /etc/openldap/slapd.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/ldap/test.ldif > /etc/openldap/test.ldif";
    assert_script_run 'sudo -u ldap slapadd -l /etc/openldap/test.ldif';
    systemctl('start slapd');
    $ldap_server_set = 1;
}

sub setup_ftp_server {
    #install and start default ftp server
    zypper_call('in vsftpd');
    systemctl('start vsftpd');
    $ftp_server_set = 1;
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    my $hostname = get_var('HOSTNAME');
    # Get variable SUPPORT_SERVER_ROLES from job settings.
    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;

    # Configure the services set in SUPPORT_SERVER_ROLES
    if (exists $server_roles{http}) {
        setup_http_server();
    }

    if (exists $server_roles{ldap}) {
        setup_ldap_server();
    }
    if (exists $server_roles{ftp}) {
        setup_ftp_server();
    }
}

1;
