# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: API client for the QNAP storage used in kernel storage tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::storage_qnap;

use strict;
use warnings;
use base 'Exporter';
use testapi qw(get_required_var get_var record_info);
use HTTP::Tiny;
use Mojo::DOM;
use MIME::Base64 'encode_base64';

our @EXPORT_OK = qw(
  create_iscsi_target
  remove_iscsi_target
  create_iscsi_lun
  remove_iscsi_lun
  map_iscsi_lun
  unmap_iscsi_lun
);

=head1 SYNOPSIS

API client for the QNAP storage used in kernel storage tests. It
provisions the storage that tests use, for example iSCSI targets and
LUNs.

QTS has no documented REST API. This module uses the CGI interface of
the QTS web UI, as the QNAP driver of OpenStack Cinder does. The calls
run from the openQA worker, not from the SUT.

Job settings: C<QNAP_USER>, C<_SECRET_QNAP_PASSWORD>, optionally
C<QNAP_PORT> (default 8080).

The calls match the requests of the QTS 5.2.4 web UI.

Each function dies if QTS reports an error, so the caller does not need
to check a return value. Each change on the QNAP is shown with
C<record_info>.

=cut

my %sid;

# Parameters the QTS 5.2 web UI sends with iSCSI changes, except LUN creation.
my %LIO = (prod => 'qts', proto => 'iscsi', target => 'lio', backend => 'dm', conf => 'ini');

sub _url {
    my ($host, $path) = @_;
    return "http://$host:" . get_var('QNAP_PORT', 8080) . "/cgi-bin/$path";
}

sub _post {
    my ($host, $path, %params) = @_;
    my $response = HTTP::Tiny->new(timeout => 60)->post_form(_url($host, $path), \%params);
    die "QNAP $host $path failed: $response->{status} $response->{reason}\n" unless $response->{success};
    return Mojo::DOM->new->xml(1)->parse($response->{content});
}

sub _login {
    my ($host) = @_;
    # Same fields as the QTS 5.2 web login. The password is only base64
    # encoded, not encrypted.
    my $dom = _post($host, 'authLogin.cgi',
        user => get_required_var('QNAP_USER'),
        pwd => encode_base64(get_required_var('_SECRET_QNAP_PASSWORD'), ''),
        serviceKey => 1,
        client_app => 'openQA',
        client_agent => 'openQA',
        dont_verify_2sv_again => 0,
    );
    my $sid = $dom->at('authSid') or die "QNAP $host login failed\n";
    $sid{$host} = $sid->text;
}

# Calls a CGI function with the session id. Logs in again once if the
# session expired. Dies if QTS returns a negative result. Shows each change
# on the QNAP, so not the extra_get reads, with record_info.
sub _request {
    my ($host, $path, %params) = @_;
    for my $try (1 .. 2) {
        _login($host) if $try == 2 || !$sid{$host};
        my $dom = _post($host, $path, %params, sid => $sid{$host});
        my $auth = $dom->at('authPassed');
        next if $auth && $auth->text eq '0';
        my $result = $dom->at('result');
        my $text = $result ? $result->text : '';
        die "QNAP $host $path $params{func} failed: result $text\n" if $text =~ /^-/;
        record_info("QNAP $params{func}", join("\n", "$path: result $text", map { "$_=$params{$_}" } grep { !exists $LIO{$_} } sort keys %params))
          unless $params{func} eq 'extra_get';
        return $dom;
    }
    die "QNAP $host login failed\n";
}

=head2 create_iscsi_target

 my $target = create_iscsi_target(host => $host, name => 'openqa', interface => 'eth1');

Creates an iSCSI target that listens on C<interface> and returns
C<< {index => ..., iqn => ...} >>. C<interface> is the QTS name of the
network adapter: QTS counts from eth0, so "Adapter 2" is eth1. CHAP is
disabled.

=cut

sub create_iscsi_target {
    my (%args) = @_;
    my $host = $args{host};
    my $interface = $args{interface} // die 'create_iscsi_target requires an interface';

    # QTS builds the IQN from a prefix, the target name and a postfix.
    my $portal = _request($host, 'disk/iscsi_portal_setting.cgi', func => 'extra_get', iSCSI_portal => 1);
    my $iqn = $portal->at('targetIQNPrefix')->text . $args{name} . $portal->at('targetIQNPostfix')->text;

    my $index = _request($host, 'disk/iscsi_target_setting.cgi', %LIO,
        func => 'add_target',
        targetIQN => $iqn,
        targetName => $iqn,
        targetAlias => $args{name},
        bTargetDataDigest => 0,
        bTargetHeaderDigest => 0,
        bTargetClusterEnable => 1,
        intf_count => 1,
        intf_1 => $interface,
    )->at('result')->text;

    _request($host, 'disk/iscsi_target_setting.cgi', %LIO,
        func => 'add_init',
        targetIndex => $index,
        initiatorIndex => 0,
        global_chap => 2,
        bCHAPEnable => 0,
        bMutualCHAPEnable => 0,
    );
    return {index => $index, iqn => $iqn};
}

=head2 remove_iscsi_target

 remove_iscsi_target(host => $host, index => $target->{index});

=cut

sub remove_iscsi_target {
    my (%args) = @_;
    _request($args{host}, 'disk/iscsi_target_setting.cgi', %LIO, func => 'remove_target', targetIndex => $args{index});
}

=head2 create_iscsi_lun

 my $lun = create_iscsi_lun(host => $host, name => 'openqa_lun0', size_gb => 10, pool => 1);

Creates a thin block-based LUN in the storage pool C<pool> (default 1)
and returns its index.

=cut

sub create_iscsi_lun {
    my (%args) = @_;
    return _request($args{host}, 'disk/iscsi_lun_setting.cgi',
        func => 'add_lun',
        FileIO => 'no',
        LUNThinAllocate => 1,
        LUNName => $args{name},
        LUNPath => $args{name},
        poolID => $args{pool} // 1,
        lv_ifssd => 'no',
        LUNCapacity => $args{size_gb},
        LUNSectorSize => 512,
        WCEnable => 0,
        FUAEnable => 0,
        enable_tiering => 0,
        lv_threshold => 80,
    )->at('result')->text;
}

=head2 remove_iscsi_lun

 remove_iscsi_lun(host => $host, index => $lun);

Removes an unmapped LUN. QTS removes it in the background.

=cut

sub remove_iscsi_lun {
    my (%args) = @_;
    _request($args{host}, 'disk/iscsi_lun_setting.cgi', %LIO,
        func => 'remove_lun', run_background => 1, LUNIndex => $args{index});
}

=head2 map_iscsi_lun

 map_iscsi_lun(host => $host, target => $target->{index}, lun => $lun);

Maps a LUN to a target.

=cut

sub map_iscsi_lun {
    my (%args) = @_;
    _request($args{host}, 'disk/iscsi_target_setting.cgi', %LIO,
        func => 'add_lun', LUNIndex => $args{lun}, targetIndex => $args{target});
}

=head2 unmap_iscsi_lun

 unmap_iscsi_lun(host => $host, target => $target->{index}, lun => $lun);

Disables a LUN and unmaps it from a target.

=cut

sub unmap_iscsi_lun {
    my (%args) = @_;
    my %ids = (LUNIndex => $args{lun}, targetIndex => $args{target});
    _request($args{host}, 'disk/iscsi_target_setting.cgi', %LIO, func => 'edit_lun', LUNEnable => 0, %ids);
    _request($args{host}, 'disk/iscsi_target_setting.cgi', %LIO, func => 'remove_lun', LUNEnable => 0, %ids);
}

1;
