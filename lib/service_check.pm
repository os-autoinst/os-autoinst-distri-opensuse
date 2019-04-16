# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check service status before and after migration.
# Maintainer: GAO WEI <wegao@suse.com>

package service_check;
use base Exporter;
use Exporter;
use testapi;
use utils;
use base 'opensusebasetest';
use strict;
use warnings;

our @EXPORT = qw(
  $hdd_base_version
  $default_services
  install_services
  check_services
);

our $hdd_base_version;
our $default_services = {
    susefirewall => {
        srv_pkg_name  => 'SuSEfirewall2',
        srv_proc_name => 'SuSEfirewall2',
        support_ver   => '12-SP3,12-SP4'
    },
    firewall => {
        srv_pkg_name  => 'firewalld',
        srv_proc_name => 'firewalld.service',
        support_ver   => '15,15-SP1'
    },
    ntp => {
        srv_pkg_name  => 'ntp',
        srv_proc_name => 'ntpd',
        support_ver   => '12-SP3,12-SP4'
    },
    chrony => {
        srv_pkg_name  => 'chrony',
        srv_proc_name => 'chronyd',
        support_ver   => '15,15-SP1'
    },
    postfix => {
        srv_pkg_name  => 'postfix',
        srv_proc_name => 'postfix',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    apache => {
        srv_pkg_name  => 'apache2',
        srv_proc_name => 'apache2',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    bind => {
        srv_pkg_name  => 'bind',
        srv_proc_name => 'named',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    snmp => {
        srv_pkg_name  => 'net-snmp',
        srv_proc_name => 'snmpd',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    nfs => {
        srv_pkg_name  => 'yast2-nfs-server',
        srv_proc_name => 'nfs',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    rpcbind => {
        srv_pkg_name  => 'rpcbind',
        srv_proc_name => 'rpcbind',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    nfs => {
        srv_pkg_name  => 'yast2-nfs-server',
        srv_proc_name => 'nfs',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    rpcbind => {
        srv_pkg_name  => 'rpcbind',
        srv_proc_name => 'rpcbind',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    autofs => {
        srv_pkg_name  => 'autofs',
        srv_proc_name => 'autofs',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    cups => {
        srv_pkg_name  => 'cups',
        srv_proc_name => 'cups',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    radvd => {
        srv_pkg_name  => 'radvd',
        srv_proc_name => 'radvd',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    cron => {
        srv_pkg_name  => 'cron',
        srv_proc_name => 'cron',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
    apparmor => {
        srv_pkg_name  => 'apparmor',
        srv_proc_name => 'apparmor',
        support_ver   => '12-SP3,12-SP4,15,15-SP1'
    },
};

sub install_services {
    my $service = shift;
    $hdd_base_version = get_var('HDDVERSION');
    foreach my $s (keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        if (grep { $_ eq $hdd_base_version } split(',', $support_ver)) {

            if ($srv_pkg_name ne 'apparmor') {
                zypper_call("in $srv_pkg_name") if $srv_pkg_name ne 'apparmor';
            }
            else {
                record_soft_failure('workaround for bug#1132292 zypper in apparmor failed msg popup');
            }

            script_run 'systemctl enable ' . $srv_proc_name;
            script_run 'systemctl start ' . $srv_proc_name;
        }
    }
}

sub check_services {
    my $service = shift;
    foreach my $s (keys %$service) {
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        if (grep { $_ eq $hdd_base_version } split(',', $support_ver)) {
            script_run 'systemctl status '
              . $srv_proc_name
              . ' --no-pager | grep active';
        }
    }
}

1;
