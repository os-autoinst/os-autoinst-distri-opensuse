# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Compare sysctl values if wicked is loaded and not. And do not allow
#          differences which are not expected, (e.g. arp_notify=1 which is set
#          by wicked, if SEND_GRATUITOUS_ARP=auto).
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wickedbase';
use testapi;
use List::Util qw(uniq);
use Mojo::File qw(path);

sub get_diff {
    my ($t1, $t2, $name1, $name2, $allow_diff) = @_;
    my %v1 = ($t1 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my %v2 = ($t2 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my @diff;

    for my $k (sort keys %v1) {
        if (exists $v2{$k}) {
            if ($v2{$k} ne $v1{$k} && !(exists $allow_diff->{$k} && $allow_diff->{$k} eq $v2{$k})) {
                push @diff, "$k differ got $name2 has '$v2{$k}' expected '$v1{$k}' as $name1";
            }
        } else {
            push @diff, "$k missing in $name2";
        }
        delete $v2{$k};
    }
    for my $k (sort keys %v2) {
        push @diff, "$k missing in $name1";
    }

    return join("\n", @diff);
}

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.68');

    my @conf_ipv6 = qw(disable_ipv6 autoconf use_tempaddr accept_ra accept_dad accept_redirects addr_gen_mode stable_secret);
    my @conf_ipv4 = qw(arp_notify accept_redirects);
    my $dummy0 = 'dummy0';
    my @interfaces = ('lo', $ctx->iface(), $dummy0);

    my $cfg = <<EOT;
STARTMODE='auto'
BOOTPROTO='static'
EOT

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), $cfg);
    $self->write_cfg("/etc/sysconfig/network/ifcfg-$dummy0", $cfg);
    $self->wicked_command('ifreload', 'all');

    my @u = sort uniq(@conf_ipv6, @conf_ipv4);
    my $cmd = <<EOT;
        for cfg in @u; do
            echo "############### \$cfg";
            sysctl -a | grep "\.\$cfg " || true;
        done
EOT

    my $out_wicked = script_output($cmd);
    $self->record_console_test_result("Sysctl Wicked", $out_wicked, result => 'ok');

    mkdir "ulogs";
    path(sprintf('ulogs/%s_%s@%s_sysctl_wicked.txt', get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spurt($out_wicked);

    # Disable wicked and reboot to get "systemd-sysctl" defaults
    script_run('systemctl disable --now wicked', die_on_timeout => 1);
    script_run('systemctl disable --now wickedd', die_on_timeout => 1);
    $self->reboot();

    assert_script_run('modprobe dummy numdummies=0');
    assert_script_run('ip link add dummy0 type dummy');
    my $out_native = script_output($cmd);

    $self->record_console_test_result("Sysctl Native", $out_native, result => 'ok');
    path(sprintf('ulogs/%s_%s@%s_sysctl_native.txt', get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spurt($out_native);

    # Wicked set `ipv4.arp_notify = 1` by default.
    my $except_diff = {'net.ipv4.conf.' . $ctx->iface() . '.arp_notify' => 1};
    my $diff = get_diff($out_native, $out_wicked, 'native', 'wicked', $except_diff);
    die("Sysctl of native and wicked defaults are different!\n" . $diff . "\n") if $diff;
}

1;
