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
use warnings;

sub fix_path {
    my $path  = shift;
    my $proto = shift;
    my @aux   = split '/', $path;

    $aux[0] .= ':' if ($proto eq 'nfs');
    $aux[0] = '//' . $aux[0] if ($proto eq 'cifs');
    $path = join '/', @aux;
}

sub is_saptune_installed {
    my $ret = script_run "rpm -q saptune";
    return (defined $ret and $ret == 0);
}

sub is_nw_profile {
    my $list = script_output "tuned-adm list";
    return ($list =~ /sap-netweaver/);
}

sub prepare_profile {
    # Will prepare system with saptune only if it's available.
    # Otherwise will try to use the 'sap-netweaver' profile
    my $has_saptune = is_saptune_installed();

    if ($has_saptune) {
        assert_script_run "tuned-adm profile saptune";
        assert_script_run "saptune solution apply NETWEAVER";
    }
    else {
        my $profile = is_nw_profile() ? 'sap-netweaver' : '$(tuned-adm recommend)';
        assert_script_run "tuned-adm profile $profile";
    }

    assert_script_run "systemctl restart systemd-logind.service";
    # 'systemctl restart systemd-logind' is causing the X11 console to move
    # out of tty2 on SLES4SAP-15, which in turn is causing the change back to
    # the previous console in post_run_hook() to fail when running on systems
    # with DESKTOP=gnome, which is a false positive as the test has already
    # finished by that step. The following prevents post_run_hook from attempting
    # to return to the console that was set before this test started. For more
    # info on why X is running in tty2 on SLES4SAP-15, see bsc#1054782
    $sles4sap::prev_console = undef;

    # If running in DESKTOP=gnome, systemd-logind restart may cause the graphical console to
    # reset and appear in SUD, so need to select 'root-console' again
    assert_screen(
        [
            qw(root-console displaymanager displaymanager-password-prompt generic-desktop
              text-login linux-login started-x-displaymanager-info)
        ]);
    select_console 'root-console' unless (match_has_tag 'root-console');

    if ($has_saptune) {
        assert_script_run "saptune daemon start";
        assert_script_run "saptune solution verify NETWEAVER";
        my $output = script_output "saptune daemon status";
        record_info("tuned status", $output);
    }
    else {
        assert_script_run "systemctl restart tuned";
    }

    my $output = script_output "tuned-adm active";
    record_info("tuned profile", $output);
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = split m|://|, get_required_var('NW');
    my @sapoptions = qw(
      SAPINST_USE_HOSTNAME=$(hostname)
      SAPINST_INPUT_PARAMETERS_URL=/sapinst/inifile.params
      SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW750.HDB.ABAPHA
      SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=false);
    my $nettout = 900;    # Time out for NetWeaver's sources related commands

    $proto = 'cifs' if ($proto eq 'smb' or $proto eq 'smbfs');
    die "netweaver_ascs_install: currently only supported protocols are nfs and smb/smbfs/cifs"
      unless ($proto eq 'nfs' or $proto eq 'cifs');

    # Normalize path depending on the protocol
    $path = fix_path($path, $proto);

    select_console 'root-console';

    # This installs Netweaver's ASCS. Start by making sure the correct
    # SAP profile and solution are configured in the system
    prepare_profile;

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
    $cmd = "../SWPM/sapinst" . ' ' . join(' ', @sapoptions);

    assert_script_run $cmd, $nettout;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
    upload_logs "/tmp/check-nw-media";
    $self->save_and_upload_log('ls -alF /sapinst/unattended', '/tmp/nw_unattended_ls.log');
    $self->save_and_upload_log('ls -alF /sbin/mount*',        '/tmp/sbin_mount_ls.log');
    upload_logs "/sapinst/unattended/sapinst.log";
    upload_logs "/sapinst/unattended/sapinst_dev.log";
}

1;
