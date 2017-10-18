# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
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
    my ($proto, $path) = split m|://|, get_var('NW');
    my @sapoptions = qw(
      SAPINST_USE_HOSTNAME=$(hostname)
      SAPINST_INPUT_PARAMETERS_URL=/sapinst/inifile.params
      SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW740SR2.ADA.PIHA
      SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=true);

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die "nw_ascs_install: currently only supported protocols are nfs and smb/smbfs/cifs"
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    # Normalize path depending on the protocol
    $path = fix_path($path, $proto);

    select_console 'root-console';

    # Copy media
    assert_script_run "mkdir /sapinst";
    assert_script_run "mount -t $proto $path /mnt";
    type_string "cd /mnt\n";
    assert_script_run "tar -cf - . | (cd /sapinst/; tar -pxf - )", 600;

    # Check everything was copied correctly
    my $cmd = q|find . -type f -exec md5sum {} \; > /tmp/check-nw-media|;
    assert_script_run $cmd, 300;
    type_string "cd /sapinst\n";
    assert_script_run "umount /mnt";
    assert_script_run "md5sum -c /tmp/check-nw-media", 300;

    # Define a valid hostname/IP address in /etc/hosts
    assert_script_run "wget -P /tmp " . autoinst_url . "/data/sles4sap/add_ip_hostname2hosts.sh";
    assert_script_run "/bin/bash -ex /tmp/add_ip_hostname2hosts.sh";

    # Use the correct hostname in SAP's inifile.params
    $cmd = q|sed -i "s/MyHostname/"$(hostname)"/" /sapinst/inifile.params|;
    assert_script_run $cmd;

    # Create an appropiate start_dir.cd file and an unattended installation directory
    $cmd = 'ls | while read d; do test -d "$d" -a ! -h "$d" && echo $d; done | sed -e "s@^@/sapinst/@"';
    assert_script_run "$cmd > /tmp/start_dir.cd";
    type_string "mkdir -p /sapinst/unattended\n";
    assert_script_run "mv /tmp/start_dir.cd /sapinst/unattended/";

    # Create sapinst group
    assert_script_run "groupadd sapinst";
    assert_script_run "chgrp -R sapinst /sapinst/unattended";
    assert_script_run "chmod -R 0775 /sapinst/unattended";

    # Set SAPADM to the SAP Admin user for future use
    my $sid = script_output "awk '/NW_GetSidNoProfiles.sid/ {print \$NF}' inifile.params", 10;
    set_var('SAPADM', lc($sid) . 'adm');

    # Start the installation
    type_string "cd /sapinst/unattended\n";
    $cmd = "../SWPM/sapinst";
    $cmd = $cmd . ' ' . join(' ', @sapoptions);

    assert_script_run $cmd, 600;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
    upload_logs "/sapinst/unattended/sapinst.log";
    upload_logs "/tmp/check-nw-media";
    $self->save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
    $self->save_and_upload_log('ls -alF /sbin/mount*',        '/tmp/sbin_mount_ls.log');
}

1;
# vim: set sw=4 et:
