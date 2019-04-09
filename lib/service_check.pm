package service_check;
use base Exporter;
use Exporter;
use testapi;
use utils;
use base 'opensusebasetest';
use strict;
use warnings;

our @EXPORT = qw(
  $default_services
  install_services
  check_services
);

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
        support_ver   => '12-SP3,12-SP4,15'
    },
};

sub install_services {
    my $service = shift;
    foreach my $s (keys %$service) {
        my $srv_pkg_name  = $service->{$s}->{srv_pkg_name};
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        if (grep { $_ eq get_var('HDDVERSION') } split(',', $support_ver)) {
            zypper_call("in $srv_pkg_name");
            assert_script_run 'systemctl enable ' . $srv_proc_name;
            assert_script_run 'systemctl start ' . $srv_proc_name;
        }
    }
}

sub check_services {
    my $service = shift;
    foreach my $s (keys %$service) {
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        my $support_ver   = $service->{$s}->{support_ver};
        if (grep { $_ eq get_var('HDDVERSION') } split(',', $support_ver)) {
            assert_script_run 'systemctl status '
              . $srv_proc_name
              . ' --no-pager | grep active';
        }
    }
}

1;
