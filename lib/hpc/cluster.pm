package hpc::cluster;
use base hpcbase;
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  provision_cluster
);

sub provision_cluster {
    my ($self) = @_;
    my $config = << "EOF";
sed -i "/^DHCLIENT_SET_HOSTNAME.*/c\\\"DHCLIENT_SET_HOSTNAME=\"no\"" /etc/sysconfig/network/dhcp
EOF
    assert_script_run($_) foreach (split /\n/, $config);
}

1;
