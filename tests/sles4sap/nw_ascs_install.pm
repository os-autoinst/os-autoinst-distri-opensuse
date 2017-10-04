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

use base "x11test";
use strict;
use testapi;

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
    my $cmd = '';

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die "nw_ascs_install: currently only supported protocols are nfs and smb/smbfs/cifs"
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    # Normalize path depending on the protocol
    $path = fix_path($path, $proto);

    x11_start_program('xterm');
    assert_screen('xterm');

    # Copy media
    assert_script_sudo("mkdir /sapinst",             10);
    assert_script_sudo("mount -t $proto $path /mnt", 30);
    type_string "cd /mnt\n";
    assert_script_sudo("tar -cf - . | (cd /sapinst/; tar -pxf - )", 600);

    # Check everything was copied correctly
    $cmd = q|find . -type f -exec md5sum {} \; > /tmp/check-nw-media|;
    assert_script_sudo($cmd, 300);
    type_string "cd /sapinst\n";
    assert_script_sudo("umount /mnt",                   10);
    assert_script_sudo("md5sum -c /tmp/check-nw-media", 300);

    # Define a valid hostname/IP address in /etc/hosts
    assert_script_run("wget -P /tmp " . autoinst_url . "/data/sles4sap/add_ip_hostname2hosts.sh");
    assert_script_sudo("/bin/bash -ex /tmp/add_ip_hostname2hosts.sh", 10);

    # Use the correct hostname in SAP's inifile.params
    $cmd = q|sed -i "s/MyHostname/"$(hostname)"/" /sapinst/inifile.params|;
    assert_script_sudo($cmd, 10);

    # Create an appropiate start_dir.cd file and an unattended installation directory
    $cmd = 'ls | while read d; do test -d "$d" -a ! -h "$d" && echo $d; done | sed -e "s@^@/sapinst/@"';
    assert_script_run("$cmd > /tmp/start_dir.cd", 10);
    type_string "mkdir -p /sapinst/unattended\n";
    assert_script_run("mv /tmp/start_dir.cd /sapinst/unattended/");

    # Create sapinst group
    assert_script_sudo("groupadd sapinst");
    assert_script_sudo("chgrp -R sapinst /sapinst/unattended");
    assert_script_sudo("chmod -R 0775 /sapinst/unattended");

    # Start the installation
    type_string "cd /sapinst/unattended\n";
    $cmd = "../SWPM/sapinst";
    $cmd = $cmd . ' ' . join(' ', @sapoptions);

    assert_script_sudo($cmd, 600);

    send_key 'alt-f4';
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
    upload_logs "/sapinst/unattended/sapinst.log";
    upload_logs "/tmp/check-nw-media";
    $self->save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
}

1;
# vim: set sw=4 et:
