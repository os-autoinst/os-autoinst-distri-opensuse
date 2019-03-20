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
    firewall => {srv_pkg_name => 'SuSEfirewall2', srv_proc_name => 'SuSEfirewall2'},
    ntp      => {srv_pkg_name => 'ntp',           srv_proc_name => 'ntpd'},
    chrony   => {srv_pkg_name => 'chrony',        srv_proc_name => 'chronyd'},
    postfix  => {srv_pkg_name => 'postfix',       srv_proc_name => 'postfix'},
};

sub install_services {
    my $service = shift;
    foreach my $s (keys %$service) {
        zypper_call("in $service->{$s}->{srv_pkg_name}");
    }
}

sub check_services {
    my $service = shift;
    foreach my $s (keys %$service) {
        my $srv_proc_name = $service->{$s}->{srv_proc_name};
        systemctl 'start ' . $srv_proc_name;
        systemctl 'status ' . $srv_proc_name;
        save_screenshot;
        assert_script_run 'systemctl status ' . $srv_proc_name . ' --no-pager | grep active';
    }
}

1;
