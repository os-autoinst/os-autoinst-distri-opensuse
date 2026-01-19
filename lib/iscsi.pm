# Copyright 2018 - 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# SUSE's openQA tests

# Summary: iSCSI server and client tools support
# - iSCSI target and LUN creation
# - iSCSI client tools
# - TGTD server is supported
# - LIO kernel server is supported
#
# Maintainer: Petr Cervinka <pcervinka@suse.com>
#             Jan Kohoutek  <jkohoutek@suse.com>

package iscsi;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use version_utils qw(check_os_release);

our @EXPORT = qw(
  iscsi_discovery
  iscsi_login
  iscsi_logout
  tgt_new_target
  tgt_new_lun
  tgt_update_lun_params
  tgt_auth_all
  tgt_show
  lio_new_target
  lio_new_lun
  lio_new_portal
  lio_auth_all
  lio_show
);

=head1 SYNOPSIS

Library for easy use of iSCSI server and client tools

=cut

=head2 iscsi_discovery

 iscsi_discovery( $target );

Runs C<iscsiadm -m discovery -t st -p $target> in the SUT,
to discover iSCSI targets on the B<$target> which could be IP address or host name

=cut

sub iscsi_discovery {
    my $target = shift;
    # iSCSI client discovery of the target
    assert_script_run("iscsiadm -m discovery -t st -p $target");
}

=head2 iscsi_login

 iscsi_login( $iqn, $target );

Runs C<iscsiadm -m node --targetname $iqn -p $target -l> in the SUT,
to login client to the iSCSI IQN B<$iqn> on the iSCSI server B<$target>

=cut

sub iscsi_login {
    my ($iqn, $target) = @_;
    # iSCSI client login into target with IQN
    assert_script_run("iscsiadm -m node --targetname $iqn -p $target -l");
}

=head2 iscsi_logout

 iscsi_logout( $iqn, $target);

Runs C<iscsiadm -m node --targetname $iqn -p $target -u> in the SUT,
to logout client from the iSCSI IQN B<$iqn> on the iSCSI server B<$target>

=cut

sub iscsi_logout {
    my ($iqn, $target) = @_;
    # iSCSI client logout from iSCSI target
    assert_script_run("iscsiadm -m node --targetname $iqn -p $target -u");
}

=head2 tgt_show

 tgt_show();

Usable only with TGTD iSCSI server
Runs the C<tgtadm --lld iscsi --op show --mode target> in the SUT,
to show up configured iSCSI LUNs

=cut

sub tgt_show {
    # Show all information about target
    assert_script_run "tgtadm --lld iscsi --op show --mode target";
}

sub tgt_new_target {
    my ($tid, $iqn) = @_;
    # Create new iSCSI target on server
    assert_script_run "tgtadm --lld iscsi --op new --mode target --tid $tid -T $iqn";
}

=head2 tgt_new_lun

 tgt_new_lun( $tid, $lun, $device );

Usable only with TGTD iSCSI server
Runs C<tgtadm --lld iscsi --op new --mode logicalunit --tid $tid --lun $lun -b $device> in the SUT,
to add new LUN B<$lun> from device B<$device> to the existing TARGET with ID B<$tid>

=cut

sub tgt_new_lun {
    my ($tid, $lun, $device) = @_;
    # Add new LUN to existing TARGET on TGT iSCSI server
    assert_script_run "tgtadm --lld iscsi --op new --mode logicalunit --tid $tid --lun $lun -b $device";
}

=head2 tgt_update_lun_params

 tgt_update_lun_params( $tid, $lun, $params );

Usable only with TGTD iSCSI server
Runs C<tgtadm --lld iscsi --op update --mode logicalunit --tid $tid --lun $lun  --params $params> in the SUT,
updates parameters B<$params> of existing LUN B<$lun> on iSCSI target ID B<$tid>

=cut

sub tgt_update_lun_params {
    my ($tid, $lun, $params) = @_;
    # Update parameters for LUN
    assert_script_run "tgtadm --lld iscsi --op update --mode logicalunit --tid $tid --lun $lun  --params $params";
}

=head2 tgt_auth_all

 tgt_auth_all( $tid );

Usable only with TGTD iSCSI server
Runs C<tgtadm --lld iscsi --op bind --mode target --tid $tid -I ALL> in the SUT,
to allow all clients to use list of targets B<$tid> on the iSCSI server

=cut

sub tgt_auth_all {
    my $tid = shift;
    # Allow all clients to use iSCSI server
    assert_script_run "tgtadm --lld iscsi --op bind --mode target --tid $tid -I ALL";
}

=head2 lio_show
 
 lio_show();

Usable only on the LIO iSCSI server
Runs C<targetcli ls iscsi> in the SUT to show up configured iSCSI LUNs

=cut

sub lio_show {
    # Show all informations about LIO iSCSI server
    assert_script_run('targetcli ls iscsi');
}

=head2 lio_new_target

 lio_new_target( $tid, $iqn );

Usable only on the LIO iSCSI server
Runs C<targetcli /iscsi create $iqn:$tid> in the SUT,
Creates new iSCSI target on LIO iSCSI server with IQN B<$iqn> and ID B<$tid>

=cut

sub lio_new_target {
    my ($tid, $iqn) = @_;
    # Create new TARGET on the LIO iSCSI server
    assert_script_run("targetcli /iscsi create $iqn:$tid");
}

=head2 lio_new_lun

 lio_new_lun( $tid, $iqn, $device );

Usable only on the LIO iSCSI server
Creates new back store from the device B<$device> (full path to) and assign it to the new LUN on target with IQN B<$iqn> and ID B<$tid> 

=cut

sub lio_new_lun {
    my ($tid, $iqn, $device) = @_;

    # Chose correct name of the iSCSI back store asset, it's iblock on SLE 12, but block since 15
    my $bs_block = check_os_release('12', 'VERSION_ID') ? 'iblock' : 'block';

    # Parse LUN name from the device path
    (my $name_lun = $device) =~ tr/\//_/;
    $name_lun =~ s/^_//;

    # Creates new LUN on LIO iSCSI server
    assert_script_run("targetcli /backstores/$bs_block create name=$name_lun dev=$device");

    # Add new LUN to the existing TARGET on LIO iSCSI server
    assert_script_run("targetcli /iscsi/$iqn:$tid/tpg1/luns create storage_object=/backstores/$bs_block/$name_lun");
}

=head2 lio_new_portal

 lio_new_portal( $tid, $iqn, $ip, $port );

Usable only on the LIO iSCSI server
Assign IP address B<$ip> and port B<$post> to the LUN on target with IQN B<$iqn> and ID B<$tid>

=cut

sub lio_new_portal {
    my ($tid, $iqn, $ip, $port) = @_;
    # Adds the LIO iSCSI server portal IP and port
    assert_script_run("targetcli /iscsi/$iqn:$tid/tpg1/portals delete 0.0.0.0 ip_port=$port") if check_os_release('15.7', 'VERSION_ID');
    assert_script_run("targetcli /iscsi/$iqn:$tid/tpg1/portals create $ip ip_port=$port");
}

=head2 lio_auth_all

 lio_auth_all( $tid, $iqn );

Usable only on the LIO iSCSI server
Allow access to all clients to use target IQN B<$iqn> with ID B<$tid> on the LIO iSCSI server

=cut

sub lio_auth_all {
    my ($tid, $iqn) = @_;
    # Enable iSCSI Demo Mode
    # With this mode, we don't need to manage iSCSI initiators
    # It's OK for a test/QA system, but of course not for a production one!
    assert_script_run("targetcli /iscsi/$iqn:$tid/tpg1 set attribute demo_mode_write_protect=0 cache_dynamic_acls=1 generate_node_acls=1 authentication=0");
}

=head2 lio_update_lun_attr

 lio_update_lun_attr( $tid, $iqn, $attribute );

Usable only on the LIO iSCSI server
Update attribute C<$attribute> on the IQN B<$iqn> with ID B<$tid> on the LIO iSCSI server

=cut

sub lio_update_lun_attr {
    my ($tid, $iqn, $attribute) = @_;
    # Update attribute(s) for LUN on the LIO iSCSI server
    assert_script_run("targetcli /iscsi/$iqn:$tid/tpg1 set attribute $attribute");
}
1;
