# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Support for iscsi target creation and iscsi client tools
# Maintainer: Petr Cervinka <pcervinka@suse.com>

package iscsi;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  iscsi_discovery
  iscsi_login
  iscsi_logout
  tgt_new_target
  tgt_new_lun
  tgt_update_lun_params
  tgt_auth_all
  tgt_show
);

sub iscsi_discovery {
    my $target = shift;
    # iscsi client discovery of the target
    assert_script_run("iscsiadm -m discovery -t st -p $target");
}

sub iscsi_login {
    my ($iqn, $target) = @_;
    # iscsi client login into target with iqn
    assert_script_run("iscsiadm -m node --targetname $iqn -p $target -l");
}

sub iscsi_logout {
    my ($iqn, $target) = @_;
    # iscsi client logout from iscsi target
    assert_script_run("iscsiadm -m node --targetname $iqn -p $target -u");
}

sub tgt_show {
    # Show all information about target
    assert_script_run "tgtadm --lld iscsi --op show --mode target";
}

sub tgt_new_target {
    my ($tid, $iqn) = @_;
    # Create new iscsi target on server
    assert_script_run "tgtadm --lld iscsi --op new --mode target --tid $tid -T $iqn";
}

sub tgt_new_lun {
    my ($tid, $lun, $device) = @_;
    # Add new lun to existing target on iscsi server
    assert_script_run "tgtadm --lld iscsi --op new --mode logicalunit --tid $tid --lun $lun -b $device";
}

sub tgt_update_lun_params {
    my ($tid, $lun, $params) = @_;
    # Update params for lun
    assert_script_run "tgtadm --lld iscsi --op update --mode logicalunit --tid $tid --lun $lun  --params $params";
}

sub tgt_auth_all {
    my $tid = shift;
    # Allow all clients to use iscsi server
    assert_script_run "tgtadm --lld iscsi --op bind --mode target --tid $tid -I ALL";
}
1;
