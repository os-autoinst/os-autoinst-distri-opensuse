=head1 service_check

check service status or service function before and after migration

=cut

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
use services::registered_addons;
use services::ntpd;
use services::cups;
use services::rpcbind;
use autofs_utils;
use services::postfix;
use kdump_utils;
use version_utils 'is_sle';

our @EXPORT = qw(
  $hdd_base_version
  $default_services
  %srv_check_results
  install_services
  check_services
);

our $hdd_base_version;
our $support_ver_def  = '12+';
our $support_ver_12   = '=12';
our $support_ver_ge15 = '15+';

our %srv_check_results = (
    before_migration => 'PASS',
    after_migration  => 'PASS',
);

our $default_services = {
    registered_addons => {
        srv_pkg_name       => 'registered_addons',
        srv_proc_name      => 'registered_addons',
        support_ver        => $support_ver_def,
        service_check_func => \&services::registered_addons::full_registered_check
    },
    susefirewall => {
        srv_pkg_name  => 'SuSEfirewall2',
        srv_proc_name => 'SuSEfirewall2',
        support_ver   => $support_ver_12
    },
    firewall => {
        srv_pkg_name  => 'firewalld',
        srv_proc_name => 'firewalld.service',
        support_ver   => $support_ver_ge15
    },
    ntp => {
        srv_pkg_name       => 'ntp',
        srv_proc_name      => 'ntpd',
        support_ver        => $support_ver_12,
        service_check_func => \&services::ntpd::full_ntpd_check
    },
    chrony => {
        srv_pkg_name  => 'chrony',
        srv_proc_name => 'chronyd',
        support_ver   => $support_ver_ge15
    },
    postfix => {
        srv_pkg_name       => 'postfix',
        srv_proc_name      => 'postfix',
        support_ver        => $support_ver_def,
        service_check_func => \&services::postfix::full_postfix_check
    },
    # Quick hack for poo 50576, we need this workround before full solution
    apache => {
        srv_pkg_name       => 'apache2',
        srv_proc_name      => 'apache2',
        support_ver        => $support_ver_def,
        service_check_func => \&services::apache::full_apache_check
    },
    dhcpd => {
        srv_pkg_name       => 'dhcp-server',
        srv_proc_name      => 'dhcpd',
        support_ver        => $support_ver_def,
        service_check_func => \&services::dhcpd::full_dhcpd_check
    },
    bind => {
        srv_pkg_name  => 'bind',
        srv_proc_name => 'named',
        support_ver   => $support_ver_def
    },
    snmp => {
        srv_pkg_name  => 'net-snmp',
        srv_proc_name => 'snmpd',
        support_ver   => $support_ver_def
    },
    nfs => {
        srv_pkg_name       => 'yast2-nfs-server',
        srv_proc_name      => 'nfs',
        support_ver        => $support_ver_def,
        service_check_func => \&check_y2_nfs_func
    },
    rpcbind => {
        srv_pkg_name       => 'rpcbind',
        srv_proc_name      => 'rpcbind',
        support_ver        => $support_ver_def,
        service_check_func => \&services::rpcbind::full_rpcbind_check
    },
    autofs => {
        srv_pkg_name       => 'autofs',
        srv_proc_name      => 'autofs',
        support_ver        => $support_ver_def,
        service_check_func => \&full_autofs_check
    },
    cups => {
        srv_pkg_name       => 'cups',
        srv_proc_name      => 'cups',
        support_ver        => $support_ver_def,
        service_check_func => \&services::cups::full_cups_check
    },
    radvd => {
        srv_pkg_name  => 'radvd',
        srv_proc_name => 'radvd',
        support_ver   => $support_ver_def
    },
    cron => {
        srv_pkg_name  => 'cron',
        srv_proc_name => 'cron',
        support_ver   => $support_ver_def
    },
    apparmor => {
        srv_pkg_name       => 'apparmor',
        srv_proc_name      => 'apparmor',
        support_ver        => $support_ver_def,
        service_check_func => \&services::apparmor::full_apparmor_check
    },
    vsftp => {
        srv_pkg_name  => 'vsftpd',
        srv_proc_name => 'vsftpd',
        support_ver   => $support_ver_def
    },
    kdump => {
        srv_pkg_name       => 'kdump',
        srv_proc_name      => 'kdump',
        support_ver        => $support_ver_def,
        service_check_func => \&full_kdump_check
    },
};

=head2 check_services

_is_applicable($srv_pkg_name);
Return false if the service test should be skipped.

By default it checks the service package name against a comma-separated
blacklist in C<EXCLUDE_SERVICES> variable and returns false if it is found there.

If C<INCLUDE_SERVICES> is set it will only return true for modules matching the
whitelist specified in a comma-separated list in C<INCLUDE_SERVICES> matching
service package name.

=cut

sub _is_applicable {
    my ($srv_pkg_name) = @_;
    if ($srv_pkg_name eq 'kdump' && check_var('ARCH', 's390x')) {
        # workaround for bsc#116300 on s390x
        record_soft_failure 'bsc#1163000 - System does not come back after crash on s390x';
        return 0;
    }
    if (get_var('EXCLUDE_SERVICES')) {
        my %excluded = map { $_ => 1 } split(/\s*,\s*/, get_var('EXCLUDE_SERVICES'));
        return 0 if $excluded{$srv_pkg_name};
    }
    if (get_var('INCLUDE_SERVICES')) {
        my %included = map { $_ => 1 } split(/\s*,\s*/, get_var('INCLUDE_SERVICES'));
        return 0 unless ($included{$srv_pkg_name});
    }
    return 1;
}

=head2 instal_services

 install_services($service);

Install services, details of default services are defined in $default_services: 

registered_addons, susefirewall, ntp, chrony, postfix, apache, dhcpd, bind, snmp, rpcbind, autofs, cups, radvd, cron, apparmor, vsftp, kdump

Check service before migration, zypper install service package, enable, start and check service status

=cut
sub install_services {
    my ($service) = @_;
    $hdd_base_version = get_var('HDDVERSION');
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        next unless _is_applicable($srv_pkg_name);
        record_info($srv_pkg_name, "service check before migration");
        eval {
            if (is_sle($support_ver, $hdd_base_version)) {
                if (exists $service->{$s}->{service_check_func}) {
                    $service->{$s}->{service_check_func}->('before');
                    next;
                }
                zypper_call "in $srv_pkg_name";
                systemctl 'enable ' . $srv_proc_name;
                systemctl 'start ' . $srv_proc_name;
                systemctl 'is-active ' . $srv_proc_name;
            }
        };
        if ($@) {
            record_info($srv_pkg_name, "failed reason: $@", result => 'fail');
            $srv_check_results{'before_migration'} = 'FAIL' if $srv_check_results{'before_migration'} eq 'PASS';
        }

    }
}

=head2 check_services

 check_services($service);

check service status after migration

=cut
sub check_services {
    my ($service) = @_;
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        next unless _is_applicable($srv_pkg_name);
        record_info($srv_pkg_name, "service check after migration");
        eval {
            if (is_sle($support_ver, $hdd_base_version)) {
                # service check after migration. if we've set up service check
                # function, we don't need following actions to check the service.
                if (exists $service->{$s}->{service_check_func}) {
                    $service->{$s}->{service_check_func}->();
                    next;
                }

                systemctl 'is-active ' . $srv_proc_name;
            }
        };
        if ($@) {
            record_info($srv_pkg_name, "failed reason: $@", result => 'fail');
            $srv_check_results{'after_migration'} = 'FAIL' if $srv_check_results{'after_migration'} eq 'PASS';
        }
    }
}

1;
