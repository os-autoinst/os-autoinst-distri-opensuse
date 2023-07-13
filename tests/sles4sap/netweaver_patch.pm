# SUSE's openQA tests
#
# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Patch SAP NetWeaver with the patches from the ./patch subdirectory
# Requires: ENV variable NW pointing to installation media
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $arch = get_required_var('ARCH');
    my $hostname = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $params_file = "/sapinst/$instance_type.params";
    my $timeout = bmwqemu::scale_timeout(900);    # Time out for NetWeaver's sources related commands
    my $product_id = undef;
    my $pscmd = $self->set_ps_cmd(get_required_var('INSTANCE_TYPE'));
    my $sap_dir = "/usr/sap/$sid";
    my $cluster_name = undef;
    $cluster_name = get_cluster_name if get_var('HA_CLUSTER');

    # Set Product ID depending on the type of Instance
    if ($instance_type eq 'ASCS') {
        $product_id = 'NW_ABAP_ASCS';
    }
    elsif ($instance_type eq 'ERS') {
        $product_id = 'NW_ERS';
    }

    select_serial_terminal;

    # The SAP Admin was set in sles4sap/netweaver_install
    $self->set_sap_info(get_required_var('INSTANCE_SID'), get_required_var('INSTANCE_ID'));

    $self->user_change;

    # start with patching only if both nodes are ready
    barrier_wait("NW_CLUSTER_PATCH_${cluster_name}_before") if ${cluster_name};

    validate_script_output("sapcontrol -nr ${instance_id} -function GetVersionInfo | tee GetVersionInfo_${instance_id}.before_patching", sub { /GetVersionInfo[\r\n]+OK/ }, title => "Versions before");

    # Patch ALL nodes from node 1
    if (!get_var('HA_CLUSTER') || get_var('HA_CLUSTER') && is_node(1)) {

        # The media mount with the patches was already done in sles4sap/netweaver_install (the patches are just in a subdir of the install media)

        # put the patches in place to get applied on SAP restart (only on one node, because it's on a shared filesystem)
        validate_script_output("/mnt/SAPCAR -gvxf '/sapinst/patches/*.sar' -R /sapmnt/${sid}/exe/uc/linux${arch}/", sub { /SAPCAR: .* extracted/ }, timeout => $timeout, title => "SAP extract");

        # stop/start to get the patches applied
        validate_script_output("sapcontrol -nr ${instance_id} -function StopSystem ALL", sub { /StopSystem[\r\n]+OK/ }, title => "StopSystem");
        $self->test_stop;

        $self->test_start;
        validate_script_output("sapcontrol -nr ${instance_id} -function StartSystem ALL", sub { /StartSystem[\r\n]+OK/ }, title => "StartSystem");
        $self->check_instance_state('green');

        # Patching ALL nodes is done now
        barrier_wait("NW_CLUSTER_PATCH_${cluster_name}") if ${cluster_name} && is_node(1);
    }

    # Node 1 does the patching, the others have to wait for that to be finished
    barrier_wait("NW_CLUSTER_PATCH_${cluster_name}") if ${cluster_name} && !is_node(1);

    validate_script_output("sapcontrol -nr ${instance_id} -function GetVersionInfo | tee GetVersionInfo_${instance_id}.after_patching", sub { /GetVersionInfo[\r\n]+OK/ }, timeout => 300, title => "Versions after");

    # compare running versions (patch levels), they should differ
    validate_script_output(
        "diff --side-by-side --width=160 --suppress-common-lines GetVersionInfo_${instance_id}.before_patching GetVersionInfo_${instance_id}.after_patching",
        sub { /patch/ },    # succeeds if at least one patch level is different after patching
        fail_message => 'Patching FAILED. The versions are the same before and after patching :-(',
        proceed_on_failure => 1,    # this needs to be here because the diff command will always find at least the difference in the timestamp
        title => "Version compare",
    );

    $self->reset_user_change;

    # go on to the next module only if patching is done on both nodes
    barrier_wait("NW_CLUSTER_PATCH_${cluster_name}_after") if ${cluster_name};
}

1;
