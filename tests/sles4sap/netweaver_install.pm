# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform an unattended installation of SAP NetWeaver
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
    my $hostname = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $params_file = "/sapinst/$instance_type.params";
    my $timeout = bmwqemu::scale_timeout(900);    # Time out for NetWeaver's sources related commands
    my $product_id = undef;

    # Set Product ID depending on the type of Instance
    if ($instance_type eq 'ASCS') {
        $product_id = 'NW_ABAP_ASCS';
    }
    elsif ($instance_type eq 'ERS') {
        $product_id = 'NW_ERS';
    }
    else {
        die "Unknown SAP NetWeaver instance type $instance_type";
    }

    my @sapoptions = qw(SAPINST_START_GUISERVER=false SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=false IS_HOST_LOCAL_USING_STRING_COMPARE=true);
    push @sapoptions, "SAPINST_USE_HOSTNAME=$hostname";
    push @sapoptions, "SAPINST_INPUT_PARAMETERS_URL=$params_file";
    push @sapoptions, "SAPINST_EXECUTE_PRODUCT_ID=$product_id:NW750.HDB.ABAPHA";

    select_serial_terminal;

    # This installs Netweaver's ASCS. Start by making sure the correct
    # SAP profile and solution are configured in the system
    $self->prepare_profile('NETWEAVER');

    # Mount media
    $self->mount_media($proto, $path, '/sapinst');

    # Define a valid hostname/IP address in /etc/hosts, but not in HA
    $self->add_hostname_to_hosts if (!get_var('HA_CLUSTER'));

    # Use the correct Hostname and InstanceNumber in SAP's params file
    # Note: $hostname can be '$(hostname)', so we need to protect with '"'
    assert_script_run "sed -i -e \"s/%HOSTNAME%/$hostname/g\" -e 's/%INSTANCE_ID%/$instance_id/g' -e 's/%INSTANCE_SID%/$sid/g' $params_file";

    # Create an appropiate start_dir.cd file and an unattended installation directory
    my $cmd = 'cd /sapinst ; ls -1 | grep -xv patch | while read d; do if [ -d "$d" -a ! -h "$d" ]; then echo $d; fi ; done | sed -e "s@^@/sapinst/@" ; cd -';
    assert_script_run 'mkdir -p /sapinst/unattended';
    assert_script_run "($cmd) > /sapinst/unattended/start_dir.cd";
    script_run 'cd -';

    # Create sapinst group
    assert_script_run "groupadd sapinst";
    assert_script_run "chgrp -R sapinst /sapinst/unattended";
    assert_script_run "chmod 0775 /sapinst/unattended";

    # Start the installation
    enter_cmd "cd /sapinst/unattended";
    $cmd = '../SWPM/sapinst ' . join(' ', @sapoptions) . " | tee sapinst_$instance_type.log";

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && !is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }

    validate_script_output(
        $cmd,
        qr{
             # On older SAP versions (known bad: NW75, known good: NW753) we have to
             # workaround an installation issue:
             # ERS installation on the second node tries to stop the ASCS server
             # but that doesn't work because ASCS is running on the first node.
             # It's "normal" and documentation says that we have to install ERS on
             # the 2nd node in order to have the SAP environment correctly set up.
             # Therefore we accept a failing return code and check the output instead.
             (
                 # This is the success pattern for newer versions (which succeed on install).
                 (
                     enserver,.EnqueueServer,.GREEN,.Running.*[\r\n]+
                     msg_server,.MessageServer,.GREEN,.Running.*[\r\n]+
                 ) | (
                     msg_server,.MessageServer,.GREEN,.Running.*[\r\n]+
                     enserver,.EnqueueServer,.GREEN,.Running.*[\r\n]+
                 )
                 .*[\r\n]+
                 .*[\r\n]+
                 Startup.of.instance.${sid}/.*.finished:.\[ACTIVE\]
             ) | (
                 # And for older versions we also allow the ASCS stop error message.
                 # ASCS00 is intentionally not a var, because this error occours on the other node.
                 stopInstanceRemote.errno=CJS-20081.*[\r\n]+
                 .*Error.when.stopping.instance.*Cannot.stop.instance.*ASCS00
             )
         }x,
        proceed_on_failure => 1,    # this is needed to succeed on faulty SAP NW versions
        timeout => $timeout,
        title => "start ${sid}",
        fail_message => "Instance ${sid}/* (${instance_type}${instance_id}) start did not succeed."
    );

    $self->upload_nw_install_log;

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }

    # Allow SAP Admin user to inform status via $testapi::serialdev
    $self->set_sap_info($sid, $instance_id);
    $self->ensure_serialdev_permissions_for_sap;
}

1;
