# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Base module for IPsec tests
# Maintainer: Kernel QE <kernel-qa@suse.de>
#
# Test requirement and topology can refer following link:
# https://github.com/linux-test-project/ltp/issues/920
# https://www.ipv6ready.org/docs/Phase2_IPsec_Interoperability_Latest.pdf

package ipsecbase;
use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Architectures;
use version_utils 'is_sle';
use lockapi;
use Utils::Logging 'save_and_upload_log';
use network_utils;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->{ipsec_id} = "0x26c44388";
    $self->{ipsec_key} = "0x6f887514ca6eccb1d273366f70b21a91aa2a3421";
    $self->{ipsec_mode} = "tunnel";
    $self->{ipsec_aead} = "'rfc4106(gcm(aes))'";
    $self->{ipsec_proto} = "esp";

    return $self;
}

sub get_net_prefix_len {
    my ($self, %args) = @_;
    my ($len) = $args{net} =~ /\/(\d+)/;
    return $len;
}

sub add_ipv6_addr {
    my ($self, %args) = @_;
    $args{dev} ||= iface();
    $args{plen} ||= 64;
    $args{ip} = $args{ip} . "/" . $args{plen};
    assert_script_run("ip -6 addr add $args{ip} dev $args{dev}");
}

sub add_ipv6_route {
    my ($self, %args) = @_;
    assert_script_run("ip -6 route add $args{dst} via $args{via}");
}

sub destroy_test_barriers {
    my ($self) = @_;
    barrier_destroy('IPSEC_IP_SETUP_DONE');
    barrier_destroy('IPSEC_ROUTE_SETUP_DONE');
    barrier_destroy('IPSEC_ROUTE_SETUP_CHECK_DONE');
    barrier_destroy('IPSEC_TUNNEL_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_SET_MTU_DONE');
    barrier_destroy('IPSEC_TUNNEL_MODE_CHECK_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_SETUP_DONE');
    barrier_destroy('IPSEC_TRANSPORT_MODE_CHECK_DONE');
}

sub check_ipv6_addr {
    my $errors = 0;
    my $tries = 10;
    my $no_ip = 1;
    my $output = '';
    while ($tries > 0 && $no_ip) {
        $no_ip = 0;
        $output = script_output('ip a');
        if ($output =~ /tentative/) {
            record_info('Waiting for IPv6 ready, still tentative state');
            $no_ip = 1;
        }
        $tries -= 1;
        sleep(5);
    }
}

sub config_ipsec {
    my ($self, $args) = @_;

    assert_script_run("ip xfrm state flush &&  ip xfrm policy flush");
    assert_script_run("ip xfrm state add src $args->{local_ip} dst $args->{remote_ip} proto $self->{ipsec_proto} spi $self->{ipsec_id} reqid $self->{ipsec_id} mode $self->{ipsec_mode} aead $self->{ipsec_aead} $self->{ipsec_key} 128");
    assert_script_run("ip xfrm state add src $args->{remote_ip} dst $args->{local_ip} proto $self->{ipsec_proto} spi $self->{ipsec_id} reqid $self->{ipsec_id} mode $self->{ipsec_mode} aead $self->{ipsec_aead} $self->{ipsec_key} 128");
    assert_script_run("ip xfrm policy add src $args->{new_local_net} dst $args->{new_remote_net} dir out tmpl src $args->{local_ip} dst $args->{remote_ip} proto $self->{ipsec_proto} reqid $self->{ipsec_id} mode $self->{ipsec_mode}");
    assert_script_run("ip xfrm policy add src $args->{new_remote_net} dst $args->{new_local_net} dir in tmpl src $args->{remote_ip} dst $args->{local_ip} proto $self->{ipsec_proto} reqid $self->{ipsec_id} mode $self->{ipsec_mode}");
}

sub pre_run_hook {
    my ($self, $args) = @_;
    select_serial_terminal;

    # disable packagekitd
    quit_packagekit();
    ensure_apparmor_disabled();

    # Stop firewall
    systemctl 'stop ' . $self->firewall;

    set_hostname(get_var('HOSTNAME', 'susetest'));

    zypper_call('install tcpdump');

    $self->SUPER::pre_run_hook;
}

sub ensure_apparmor_disabled () {
    unless (systemctl "is-active apparmor", proceed_on_failure => 1) {    # 0 if active, unless to revert
        systemctl "disable --now apparmor";
        record_info "apparmor", "disabled";
    }
}

1;
