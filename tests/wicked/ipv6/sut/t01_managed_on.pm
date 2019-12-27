# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: IPv6 - Managed on, prefix length != 64, RDNSS
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use Regexp::Common 'net';

sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface());
    assert_script_run('rdisc6 ' . $ctx->iface());
    $self->wicked_command('ifdown', $ctx->iface());
    $self->wicked_command('ifup',   $ctx->iface());
    my $gateway             = $self->get_remote_ip(type => 'gateway');
    my $ipv6_network_prefix = $self->get_ip(type => 'ipv6');
    my $ipv6_dns            = $self->get_ip(type => 'dns_advice');
    my $output              = script_output('ip a s dev ' . $ctx->iface());
    my $errors              = 0;
    unless ($output =~ /inet $RE{net}{IPv4}/) {
        record_info('FAIL', 'IPv4 address absent', result => 'fail');
        $errors = 1;
    }
    unless ($output =~ /inet6 $RE{net}{IPv6}/) {
        record_info('FAIL', 'IPv6 address absent', result => 'fail');
        $errors = 1;
    }
    unless ($output !~ /tentative/) {
        record_info('FAIL', 'tentative word presented', result => 'fail');
        $errors = 1;
    }

    $output = script_output('ip -6 r s');

    unless ($output =~ /^default/m) {
        record_info('FAIL', 'no default route presented', result => 'fail');
        $errors = 1;
    }
    unless ($output =~ /^$ipv6_network_prefix/m) {
        record_info('FAIL', 'no prefix for local network route', result => 'fail');
        $errors = 1;
    }

    $output = script_output('ip -6 -o r s');

    unless ($output =~ /^default.*proto ra/m) {
        record_info('FAIL', 'IPv6 default route comes not from RA', result => 'fail');
        $errors = 1;
    }

    my $timeout     = 10;
    my $dns_failure = 1;
    while ($timeout > 0 && $dns_failure) {
        $dns_failure = 0;
        $output      = script_output('cat /etc/resolv.conf');

        unless ($output =~ /^nameserver $gateway/m) {
            record_info('Waiting IPv4 DNS', 'IPv4 DNS is missing in resolv.conf');
            $dns_failure = 1;
        }

        unless ($output =~ /^nameserver $ipv6_dns/m) {
            record_info('Waiting IPv6 DNS', 'IPv6 is missing in resolv.conf');
            $dns_failure = 1;
        }
        $timeout -= 1;
        sleep(1);
    }

    if ($dns_failure) {
        record_soft_failure("glab#57 (https://gitlab.suse.de/wicked-maintainers/wicked/issues/57) IPv6 DNS advise was not applied");
    }
    die "There were errors during test" if $errors;

}

sub test_flags {
    return {always_rollback => 1};
}

1;
