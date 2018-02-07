# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Perform an unattended installation of SAP NetWeaver ASCS
# Requires: ENV variable NW pointing to installation media
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use strict;

sub fix_path {
    my $path  = shift;
    my $proto = shift;
    my @aux   = split '/', $path;

    $aux[0] .= ':' if ($proto eq 'nfs');
    $aux[0] = '//' . $aux[0] if ($proto eq 'cifs');
    $path = join '/', @aux;
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = split m|://|, get_required_var('NW');
    my @sapoptions = qw(
      SAPINST_USE_HOSTNAME=$(hostname)
      SAPINST_INPUT_PARAMETERS_URL=/sapinst/inifile.params
      SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW750.HDB.ABAPHA
      SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=false);
    my $nettout = 600;    # Time out for NetWeaver's sources related commands

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die "netweaver_ascs_install: currently only supported protocols are nfs and smb/smbfs/cifs"
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    # Normalize path depending on the protocol
    $path = fix_path($path, $proto);

    select_console 'root-console';

    # This installs Netweaver's ASCS. Start by making sure the correct
    # SAP profile and solution are configured in the system
    assert_script_run "tuned-adm profile sap-netweaver";
    assert_script_run "saptune solution apply NETWEAVER";
    assert_script_run q/kill -1 $(ps aux|grep systemd-logind|awk '{print $2}'|head -1)/;
    assert_script_run "saptune daemon start";
    assert_script_run "saptune solution verify NETWEAVER";
    my $output = script_output "tuned-adm active";
    record_info("tuned profile", $output);
    $output = script_output "saptune daemon status";
    record_info("tuned status", $output);

    # Copy media
    assert_script_run "mkdir /sapinst";
    assert_script_run "mount -t $proto $path /mnt";
    type_string "cd /mnt\n";
    type_string "cd " . get_var('ARCH') . "\n";    # Change to ARCH specific subdir if exists
    assert_script_run "tar -cf - . | (cd /sapinst/; tar -pxf - )", $nettout;

    # Check everything was copied correctly
    my $cmd = q|find . -type f -exec md5sum {} \; > /tmp/check-nw-media|;
    assert_script_run $cmd, $nettout;
    type_string "cd /sapinst\n";
    assert_script_run "umount /mnt";
    assert_script_run "md5sum -c /tmp/check-nw-media", $nettout;

    # Define a valid hostname/IP address in /etc/hosts
    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/add_ip_hostname2hosts.sh > /tmp/add_ip_hostname2hosts.sh";
    assert_script_run "/bin/bash -ex /tmp/add_ip_hostname2hosts.sh";

    # Use the correct hostname in SAP's inifile.params
    $cmd = q|sed -i "s/MyHostname/"$(hostname)"/" /sapinst/inifile.params|;
    assert_script_run $cmd;

    # Create an appropiate start_dir.cd file and an unattended installation directory
    $cmd = 'ls | while read d; do if [ -d "$d" -a ! -h "$d" ]; then echo $d; fi ; done | sed -e "s@^@/sapinst/@"';
    assert_script_run "$cmd > /tmp/start_dir.cd";
    type_string "mkdir -p /sapinst/unattended\n";
    assert_script_run "mv /tmp/start_dir.cd /sapinst/unattended/";

    # Create sapinst group
    assert_script_run "groupadd sapinst";
    assert_script_run "chgrp -R sapinst /sapinst/unattended";
    assert_script_run "chmod -R 0775 /sapinst/unattended";

    # Set SAPADM to the SAP Admin user for future use
    my $sid = script_output q|awk '/NW_GetSidNoProfiles.sid/ {print $NF}' inifile.params|, 10;
    set_var('SAPADM', lc($sid) . 'adm');

    # Start the installation
    type_string "cd /sapinst/unattended\n";
    $cmd = "../SWPM/sapinst";
    $cmd = $cmd . ' ' . join(' ', @sapoptions);

    assert_script_run $cmd, $nettout;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
    upload_logs "/tmp/check-nw-media";
    $self->save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
    $self->save_and_upload_log('ls -alF /sbin/mount*',        '/tmp/sbin_mount_ls.log');
    upload_logs "/sapinst/unattended/sapinst.log";
}

1;
# vim: set sw=4 et:
