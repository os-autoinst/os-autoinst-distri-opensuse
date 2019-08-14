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

use Exporter 'import';
use testapi;
use utils;
use base 'opensusebasetest';
use strict;
use warnings;
use services::apache;
use services::apparmor;
use services::dhcpd;
use nfs_common;
use services::ntpd;

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
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5'
    },
    firewall => {
        srv_pkg_name  => 'firewalld',
        srv_proc_name => 'firewalld.service',
        support_ver   => '15,15-SP1'
    },
    ntp => {
        srv_pkg_name       => 'ntp',
        srv_proc_name      => 'ntpd',
        support_ver        => '12-SP2,12-SP3,12-SP4,12-SP5',
        service_check_func => \&services::ntpd::full_ntpd_check
    },
    chrony => {
        srv_pkg_name  => 'chrony',
        srv_proc_name => 'chronyd',
        support_ver   => '15,15-SP1'
    },
    postfix => {
        srv_pkg_name  => 'postfix',
        srv_proc_name => 'postfix',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    # Quick hack for poo 50576, we need this workround before full solution
    apache => {
        srv_pkg_name       => 'apache2',
        srv_proc_name      => 'apache2',
        support_ver        => '12-SP2,12-SP3,12-SP4,15,15-SP1',
        service_check_func => \&services::apache::full_apache_check
    },
    dhcpd => {
        srv_pkg_name       => 'dhcp-server',
        srv_proc_name      => 'dhcpd',
        support_ver        => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1',
        service_check_func => \&services::dhcpd::full_dhcpd_check
    },
    bind => {
        srv_pkg_name  => 'bind',
        srv_proc_name => 'named',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    snmp => {
        srv_pkg_name  => 'net-snmp',
        srv_proc_name => 'snmpd',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    nfs => {
        srv_pkg_name       => 'yast2-nfs-server',
        srv_proc_name      => 'nfs',
        support_ver        => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1',
        service_check_func => \&check_y2_nfs_func
    },
    rpcbind => {
        srv_pkg_name  => 'rpcbind',
        srv_proc_name => 'rpcbind',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    rpcbind => {
        srv_pkg_name  => 'rpcbind',
        srv_proc_name => 'rpcbind',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    autofs => {
        srv_pkg_name  => 'autofs',
        srv_proc_name => 'autofs',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    cups => {
        srv_pkg_name  => 'cups',
        srv_proc_name => 'cups',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    radvd => {
        srv_pkg_name  => 'radvd',
        srv_proc_name => 'radvd',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    cron => {
        srv_pkg_name  => 'cron',
        srv_proc_name => 'cron',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
    apparmor => {
        srv_pkg_name       => 'apparmor',
        srv_proc_name      => 'apparmor',
        support_ver        => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1',
        service_check_func => \&services::apparmor::full_apparmor_check
    },
    vsftp => {
        srv_pkg_name  => 'vsftpd',
        srv_proc_name => 'vsftpd',
        support_ver   => '12-SP2,12-SP3,12-SP4,12-SP5,15,15-SP1'
    },
};

sub install_services {
    my ($service) = @_;
    $hdd_base_version = get_var('HDDVERSION');
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        record_info($srv_pkg_name, "service check before migration");
        if (grep { $_ eq $hdd_base_version } split(',', $support_ver)) {
            if (exists $service->{$s}->{service_check_func}) {
                $service->{$s}->{service_check_func}->('before');
                next;
            }

            systemctl 'start ' . $srv_proc_name;
            systemctl 'is-active ' . $srv_proc_name;
        }
    }
}

sub check_services {
    my ($service) = @_;
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        record_info($srv_pkg_name, "service check after migration");
        if (grep { $_ eq $hdd_base_version } split(',', $support_ver)) {
            # service check after migration. if we've set up service check
            # function, we don't need following actions to check the service.
            if (exists $service->{$s}->{service_check_func}) {
                $service->{$s}->{service_check_func}->();
                next;
            }

            systemctl 'is-active ' . $srv_proc_name;
        }
    }
}

1;
