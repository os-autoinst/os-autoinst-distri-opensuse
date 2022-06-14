=head1 service_check

check service status or service function before and after migration

=cut

# SUSE's openQA tests
#
# Copyright 2021-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: check service status before and after migration.
# Maintainer: GAO WEI <wegao@suse.com>

package service_check;

use Exporter 'import';
use testapi;
use Utils::Architectures;
use utils;
use base 'opensusebasetest';
use strict;
use warnings;
use services::docker;
use services::apache;
use services::apparmor;
use services::dhcpd;
use nfs_common;
use services::registered_addons;
use services::hpcpackage_remain;
use services::ntpd;
use services::nodejs;
use services::cups;
use services::rpcbind;
use services::users;
use services::sshd;
use autofs_utils;
use services::postfix;
use services::firewall;
use services::libvirtd;
use kdump_utils;
use version_utils 'is_sle';
use x11utils;

our @EXPORT = qw(
  $default_services
  %srv_check_results
  install_services
  check_services
);

our $support_ver_def = '12+';
our $support_ver_12 = '=12';
our $support_ver_ge15 = '15+';
our $support_ver_ge12 = '12+';
our $support_ver_ge11 = '11+';
our $support_ver_lt15 = '<15';

our %srv_check_results = (
    before_migration => 'PASS',
    after_migration => 'PASS',
);

our $default_services = {
    sshd => {
        srv_pkg_name => 'sshd',
        srv_proc_name => 'sshd',
        support_ver => $support_ver_ge15,
        service_check_func => \&services::sshd::full_sshd_check,
        service_cleanup_func => \&services::sshd::sshd_cleanup
    },
    docker => {
        srv_pkg_name => 'docker',
        srv_proc_name => 'docker',
        support_ver => $support_ver_ge12,
        service_check_func => \&services::docker::full_docker_check,
    },
    users => {
        srv_pkg_name => 'users',
        srv_proc_name => 'users',
        support_ver => $support_ver_ge12,
        service_check_func => \&services::users::full_users_check,
        service_cleanup_func => \&services::users::users_cleanup
    },
    hpcpackage_remain => {
        srv_pkg_name => 'hpcpackage_remain',
        srv_proc_name => 'hpcpackage_remain',
        support_ver => $support_ver_ge15,
        service_check_func => \&services::hpcpackage_remain::full_pkgcompare_check,
        service_cleanup_func => \&services::hpcpackage_remain::hpcpkg_cleanup
    },
    registered_addons => {
        srv_pkg_name => 'registered_addons',
        srv_proc_name => 'registered_addons',
        support_ver => $support_ver_def,
        service_check_func => \&services::registered_addons::full_registered_check
    },
    susefirewall => {
        srv_pkg_name => 'SuSEfirewall2',
        srv_proc_name => 'SuSEfirewall2',
        support_ver => $support_ver_lt15,
        service_check_func => \&services::firewall::full_firewall_check
    },
    firewall => {
        srv_pkg_name => 'firewalld',
        srv_proc_name => 'firewalld.service',
        support_ver => $support_ver_ge15
    },
    ntp => {
        srv_pkg_name => 'ntp',
        srv_proc_name => 'ntpd',
        support_ver => $support_ver_lt15,
        service_check_func => \&services::ntpd::full_ntpd_check
    },
    chrony => {
        srv_pkg_name => 'chrony',
        srv_proc_name => 'chronyd',
        support_ver => $support_ver_ge15
    },
    postfix => {
        srv_pkg_name => 'postfix',
        srv_proc_name => 'postfix',
        support_ver => $support_ver_def,
        service_check_func => \&services::postfix::full_postfix_check
    },
    # Quick hack for poo 50576, we need this workround before full solution
    apache => {
        srv_pkg_name => 'apache2',
        srv_proc_name => 'apache2',
        support_ver => $support_ver_ge11,
        service_check_func => \&services::apache::full_apache_check
    },
    dhcpd => {
        srv_pkg_name => 'dhcp-server',
        srv_proc_name => 'dhcpd',
        support_ver => $support_ver_ge11,
        service_check_func => \&services::dhcpd::full_dhcpd_check
    },
    bind => {
        srv_pkg_name => 'bind',
        srv_proc_name => 'named',
        support_ver => $support_ver_ge11
    },
    snmp => {
        srv_pkg_name => 'net-snmp',
        srv_proc_name => 'snmpd',
        support_ver => $support_ver_def
    },
    nfs => {
        srv_pkg_name => 'yast2-nfs-server',
        srv_proc_name => 'nfs',
        support_ver => $support_ver_def,
        service_check_func => \&check_y2_nfs_func
    },
    nodejs => {
        srv_pkg_name => 'nodejs',
        srv_proc_name => 'nodejs',
        support_ver => '>=15-SP3',
        service_check_func => \&services::nodejs::full_nodejs_check
    },
    rpcbind => {
        srv_pkg_name => 'rpcbind',
        srv_proc_name => 'rpcbind',
        support_ver => $support_ver_ge11,
        service_check_func => \&services::rpcbind::full_rpcbind_check
    },
    autofs => {
        srv_pkg_name => 'autofs',
        srv_proc_name => 'autofs',
        support_ver => $support_ver_ge11,
        service_check_func => \&full_autofs_check
    },
    cups => {
        srv_pkg_name => 'cups',
        srv_proc_name => 'cups',
        support_ver => $support_ver_ge11,
        service_check_func => \&services::cups::full_cups_check
    },
    radvd => {
        srv_pkg_name => 'radvd',
        srv_proc_name => 'radvd',
        support_ver => $support_ver_ge11
    },
    cron => {
        srv_pkg_name => 'cron',
        srv_proc_name => 'cron',
        support_ver => $support_ver_ge11
    },
    apparmor => {
        srv_pkg_name => 'apparmor',
        srv_proc_name => 'apparmor',
        support_ver => $support_ver_ge12,
        service_check_func => \&services::apparmor::full_apparmor_check
    },
    vsftp => {
        srv_pkg_name => 'vsftpd',
        srv_proc_name => 'vsftpd',
        support_ver => $support_ver_def
    },
    kdump => {
        srv_pkg_name => 'kdump',
        srv_proc_name => 'kdump',
        support_ver => $support_ver_def,
        service_check_func => \&full_kdump_check
    },
    libvirtd => {
        srv_pkg_name => 'libvirtd',
        srv_proc_name => 'libvirtd',
        support_ver => $support_ver_def,
        service_check_func => \&services::libvirtd::full_libvirtd_check
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
    if ($srv_pkg_name eq 'kdump' && is_s390x) {
        # workaround for bsc#116300 on s390x
        record_soft_failure 'bsc#1163000 - System does not come back after crash on s390x';
        return 0;
    }
    # This feature is used only by hpc
    return 0 if ($srv_pkg_name eq 'hpcpackage_remain' && !check_var('SLE_PRODUCT', 'hpc'));
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
    opensusebasetest::select_serial_terminal() if (get_var('SEL_SERIAL_CONSOLE'));
    # turn off lmod shell debug information
    assert_script_run('echo export LMOD_SH_DBG_ON=1 >> /etc/bash.bashrc.local');
    # turn off screen saver
    if (check_var('DESKTOP', 'gnome')) {
        if (is_s390x) {
            turn_off_gnome_screensaver;
        }
        else {
            turn_off_gnome_screensaver_for_running_gdm;
        }
    }
    # On ppc64le, sometime the console font will be distorted into pseudo graphics characters.
    # we need to reset the console font. As it impacted all the console services, added this command to bashrc file
    assert_script_run('echo /usr/lib/systemd/systemd-vconsole-setup >> /etc/bash.bashrc.local') if is_ppc64le;
    assert_script_run '. /etc/bash.bashrc.local';
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver = $service->{$s}->{support_ver};
        my $service_type = 'SystemV';
        next unless _is_applicable($srv_pkg_name);
        record_info($srv_pkg_name, "service check before migration");
        # We assume this service $service->{$s} passed at install_service
        $service->{$s}->{before_migration} = 'PASS';
        eval {
            if (is_sle($support_ver, get_var('ORIGIN_SYSTEM_VERSION'))) {
                if (check_var('ORIGIN_SYSTEM_VERSION', '11-SP4')) {
                    $service_type = 'SystemV';
                    # Enable IPv6 forwarding on sle11sp4
                    script_run('echo 1 > /proc/sys/net/ipv6/conf/all/forwarding') if ($srv_pkg_name eq 'radvd');
                }
                else {
                    $service_type = 'Systemd';
                }
                if (exists $service->{$s}->{service_check_func}) {
                    $service->{$s}->{service_check_func}->(%{$service->{$s}}, service_type => $service_type, stage => 'before');
                    next;
                }
                zypper_call "in $srv_pkg_name";
                common_service_action($srv_proc_name, $service_type, 'enable');
                common_service_action($srv_proc_name, $service_type, 'start');
                common_service_action($srv_proc_name, $service_type, 'is-active');
            }
        };
        if ($@) {
            # This service $service->{$s} failed at install_service
            $service->{$s}->{before_migration} = 'FAIL';
            if (exists $service->{$s}->{service_cleanup_func}) {
                $service->{$s}->{service_cleanup_func}->(%{$service->{$s}}, service_type => $service_type, stage => 'before');
            }
            record_info($srv_pkg_name, "failed reason: $@", result => 'fail');
            $srv_check_results{'before_migration'} = 'FAIL';
        }
    }
    # Keep the configuration file clean
    if (is_ppc64le) {
        assert_script_run("sed -i '\$d' /etc/bash.bashrc.local");
        assert_script_run '. /etc/bash.bashrc.local';
    }
}

=head2 check_services

 check_services($service);

check service status after migration

=cut

sub check_services {
    my ($service) = @_;
    foreach my $s (sort keys %$service) {
        my $srv_pkg_name = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver = $service->{$s}->{support_ver};
        my $service_type = 'Systemd';
        next unless (_is_applicable($srv_pkg_name) && (($service->{$s}->{before_migration} eq 'PASS') || get_var('START_AFTER_TEST')));
        record_info($srv_pkg_name, "service check after migration");
        eval {
            if (is_sle($support_ver, get_var('ORIGIN_SYSTEM_VERSION'))) {
                # service check after migration. if we've set up service check
                # function, we don't need following actions to check the service.
                if (exists $service->{$s}->{service_check_func}) {
                    $service->{$s}->{service_check_func}->(%{$service->{$s}}, service_type => $service_type, stage => 'after');
                    next;
                }
                common_service_action($srv_proc_name, $service_type, 'is-active');
            }
        };
        if ($@) {
            if (exists $service->{$s}->{service_cleanup_func}) {
                $service->{$s}->{service_cleanup_func}->(%{$service->{$s}}, service_type => $service_type, stage => 'after');
            }
            record_info($srv_pkg_name, "failed reason: $@", result => 'fail');
            $srv_check_results{'after_migration'} = 'FAIL';
        }
    }
}

1;
