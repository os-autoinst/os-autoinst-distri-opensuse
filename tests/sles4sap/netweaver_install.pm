# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Perform an unattended installation of SAP NetWeaver
# Requires: ENV variable NW pointing to installation media
# Maintainer: Alvaro Carvajal <acarvajal@suse.de> / Loic Devulder <ldevulder@suse.de>

use base "sles4sap";
use testapi;
use lockapi;
use hacluster;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id   = get_required_var('INSTANCE_ID');
    my $sid           = get_required_var('INSTANCE_SID');
    my $hostname      = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $params_file   = "/sapinst/$instance_type.params";
    my $nettout       = 900;                                        # Time out for NetWeaver's sources related commands
    my $product_id    = undef;

    # Set Product ID depending on the type of Instance
    if ($instance_type eq 'ASCS') {
        $product_id = 'NW_ABAP_ASCS';
    }
    elsif ($instance_type eq 'ERS') {
        $product_id = 'NW_ERS';
    }

    my @sapoptions = qw(SAPINST_START_GUISERVER=false SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=false);
    push @sapoptions, "SAPINST_USE_HOSTNAME=$hostname";
    push @sapoptions, "SAPINST_INPUT_PARAMETERS_URL=$params_file";
    push @sapoptions, "SAPINST_EXECUTE_PRODUCT_ID=$product_id:NW750.HDB.ABAPHA";

    $self->select_serial_terminal;

    # This installs Netweaver's ASCS. Start by making sure the correct
    # SAP profile and solution are configured in the system
    $self->prepare_profile('NETWEAVER');

    # Copy media
    $self->copy_media($proto, $path, $nettout, '/sapinst');

    # Define a valid hostname/IP address in /etc/hosts, but not in HA
    if (!get_var('HA_CLUSTER')) {
        assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/add_ip_hostname2hosts.sh > /tmp/add_ip_hostname2hosts.sh";
        assert_script_run "/bin/bash -ex /tmp/add_ip_hostname2hosts.sh";
    }

    # Use the correct Hostname and InstanceNumber in SAP's params file
    # Note: $hostname can be '$(hostname)', so we need to protect with '"'
    assert_script_run "sed -i -e \"s/%HOSTNAME%/$hostname/g\" -e 's/%INSTANCE_ID%/$instance_id/g' -e 's/%INSTANCE_SID%/$sid/g' $params_file";

    # Create an appropiate start_dir.cd file and an unattended installation directory
    my $cmd = 'ls | while read d; do if [ -d "$d" -a ! -h "$d" ]; then echo $d; fi ; done | sed -e "s@^@/sapinst/@"';
    assert_script_run 'mkdir -p /sapinst/unattended';
    assert_script_run "$cmd > /sapinst/unattended/start_dir.cd";

    # Create sapinst group
    assert_script_run "groupadd sapinst";
    assert_script_run "chgrp -R sapinst /sapinst/unattended";
    assert_script_run "chmod 0775 /sapinst/unattended";

    # Start the installation
    type_string "cd /sapinst/unattended\n";
    $cmd = '../SWPM/sapinst ' . join(' ', @sapoptions);

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && !is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }

    if ($instance_type eq 'ASCS') {
        assert_script_run $cmd, $nettout;
    }
    elsif ($instance_type eq 'ERS') {
        # We have to workaround an installation issue:
        # ERS installation try to stop the ASCS server but that doesn't work
        #  because ASCS is running on the first node!
        # It's "normal" and documentation says that we have to install ERS on the 2nd node
        #  in order to have the SAP environment correctly set-up.
        script_run $cmd, $nettout;

        # So we have to check in the log file that's the installation goes well
        # We simply checking for the ASCS stop error message!
        # TODO: maybe change this to something more robust!
        assert_script_run "grep -q 'Cannot stop instance.*ASCS' /sapinst/unattended/sapinst.log";
    }

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }
}

{
    no warnings 'redefine';
    sub post_fail_hook {
        my $self = shift;

        $self->export_logs();
        upload_logs "/tmp/check-nw-media";
        $self->save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
        $self->save_and_upload_log('ls -alF /sbin/mount*',        '/tmp/sbin_mount_ls.log');
        upload_logs "/sapinst/unattended/sapinst.log";
        upload_logs "/sapinst/unattended/sapinst_dev.log";
        upload_logs "/sapinst/unattended/start_dir.cd";
    }
}

1;
