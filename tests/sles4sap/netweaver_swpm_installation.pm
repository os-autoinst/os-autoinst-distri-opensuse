# SUSE's SLES4SAP openQA tests

#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems for ENSA2 based installation
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster;
use strict;
use warnings;

sub raise_barriers {
    my (%args) = @_;
    my @instances = $args{instances};
    my $instance_type = $args{instance_type};
    # ASCS needs to be installed before ERS, PAS, AAS. Hana DB can be installed in parallel.
    foreach (@instances) { barrier_wait('SAPINST_ASCS') if $instance_type ne 'ASCS'; }
    foreach (@instances) { barrier_wait('SAPINST_ERS') if grep(/$instance_type/, ('PAS', 'HDB', 'AAS'))
          and grep('ERS', @instances); };    # Only if ERS is being installed with APP servers
    foreach (@instances) { barrier_wait('SAPINST_HDB') if grep(/$instance_type/, ('PAS', 'AAS')); };    # PAS and AAS waits for HDB export
    barrier_wait('SAPINST_PAS') if $instance_type eq 'AAS';    # Only AAS waits for PAS
}

sub release_barrier {
    my (%args) = @_;
    my @instances = $args{instances};
    my $instance_type = $args{instance_type};
    barrier_wait('SAPINST_ASCS') if $instance_type eq 'ASCS';    # release ASCS barrier
    barrier_wait('SAPINST_ERS') if $instance_type eq 'ERS' and grep(/PAS/, @instances);    # release ERS barrier if PAS was part of setup
    barrier_wait('SAPINST_HDB') if $instance_type eq 'HDB' and grep(/PAS/, @instances);    # release HDB barrier if PAS was part of setup
    barrier_wait('SAPINST_PAS') if $instance_type eq 'PAS' and grep(/AAS/, @instances);    # release PAS barrier if AAS was part of setup
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $nw_install_data = $self->netweaver_installation_data();
    my $instance_data = $nw_install_data->{instances}{$instance_type};
    my $hostname = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $media_mount_point = '/sapinst';

    my $sar_archives_dir = $media_mount_point . '/' . get_var('SAR_SOURCES', 'SAR_SOURCES'); # relative path from NFS root to the DIR with KERNEL, SWPM... SAR archives
    my $sapcar_bin = $media_mount_point . '/' . get_var('SAPCAR_BIN', 'SAPCAR');    # relative path from NFS root to SAPCAR binary
    my $swpm_sar_filename = get_required_var('SWPM_SAR_FILENAME');
    my $sapinst_unpack_path = '/tmp/SWPM';
    my $sap_install_profile = "$sapinst_unpack_path/inifile.params";

    my $product_id = $instance_data->{product_id};
    my $sap_install_profile_template = join('/', $media_mount_point, get_var('SAP_PROFILE_DIR', 'sap_install_profiles'),
        $instance_type . '_inifile.params');

    select_serial_terminal;
    record_info('Media mount', 'Mounting installation media');
    $self->mount_media($proto, $path, $media_mount_point);
    my $swpm_binary = $self->prepare_swpm(sapcar_bin_path => $sapcar_bin,
        sar_archives_dir => $sar_archives_dir,
        swpm_sar_filename => $swpm_sar_filename,
        target_path => $sapinst_unpack_path
    );

    record_info('Profiles', 'Preparing installation profiles for SAP software provisioning manager');
    $self->prepare_sapinst_profile(
        profile_target_file => $sap_install_profile,
        profile_template_file => $sap_install_profile_template,
        sar_location_directory => $sapinst_unpack_path,
        instance_type => $instance_type
    );

    $self->share_hosts_entry();
    barrier_wait('SAPINST_SYNC_NODES');    # Sync all nodes before installation start
    $self->add_hosts_file_entries();    # Each node creates a file with ow host entry on NFS

    my @instances = keys %{$nw_install_data->{instances}};
    # Raises instance specific barrier to prevent dependencies from running
    raise_barriers(instance_type => $instance_type, instances => @instances);

    my $swpm_command = join(' ', $swpm_binary,
        "SAPINST_INPUT_PARAMETERS_URL=$sap_install_profile",
        "SAPINST_USE_HOSTNAME=$hostname",
        'SAPINST_SKIP_DIALOGS=true',
        "SAPINST_EXECUTE_PRODUCT_ID=$product_id",
        '-nogui',
        '-noguiserver');

    record_info('SAPINST EXEC', "Executing sapinst command:\n$swpm_command");
    assert_script_run($swpm_command);

    $self->sapcontrol_process_check(sidadm => $nw_install_data->{sidadm},
        instance_id => $instance_data->{instance_id},
        expected_state => 'started');

    # releases instance specific barrier to signal installation being done and let dependencies continue
    release_barrier(instance_type => $instance_type, instances => @instances);
    # sync all nodes after installation done and show status info on SAP instances
    barrier_wait('SAPINST_INSTALLATION_FINISHED');
    $self->sap_show_status_info(netweaver => 1, instance_id => $instance_data->{instance_id})
      if grep($instance_type, ('ERS', 'ASCS', 'PAS', 'AAS'));
}

1;
