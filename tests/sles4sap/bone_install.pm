# SUSE's SLES4SAP openQA tests
#
# Copyright 2019-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SAP Business One via command line.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils qw(file_content_replace zypper_call);
use Utils::Systemd 'systemctl';
use version_utils 'is_sle';
use POSIX 'ceil';
use Utils::Logging 'save_and_upload_log';
#use base "x11test";

=head2 download_hana_assets_from_server

  download_hana_assets_from_server()

Download and extract HANA installation media to /sapinst directory of the SUT.
The media location must be provided as ASSET_0 in the job settings and be
available as an uncompressed tar in the factory/other directory of the openQA
server

=cut

sub download_hana_assets_from_server {
    my $target = $_{target} // '/sapinst';
    my $nettout = $_{nettout} // 2700;
    script_run "mkdir $target";
    assert_script_run "cd $target";
    my $filename = get_required_var('ASSET_0');
    my $hana_location = data_url('ASSET_0');
    # Each HANA asset is about 16GB. A ten minute timeout assumes a generous
    # 27.3MB/s download speed. Adjust according to expected server conditions.
    assert_script_run "wget -O - $hana_location | tar -xf -", timeout => $nettout;
    # Skip checksum check if DISABLE_CHECKSUM is set, or if checksum file is not
    # part of the archive
    my $sap_chksum_file = 'MD5FILE.DAT';
    my $chksum_file = 'checksum.md5sum';
    my $no_checksum_file = script_run "[[ -f $target/$chksum_file || -f $target/$sap_chksum_file ]]";
    return 1 if (get_var('DISABLE_CHECKSUM') || $no_checksum_file);

    # Switch to $target to verify copied contents are OK
    assert_script_run "pushd $target";
    # If SAP provided MD5 sum file is present convert it to the md5sum format
    assert_script_run "[[ -f $sap_chksum_file ]] && awk '{print \$2\" \"\$1}' $target/$sap_chksum_file > $target/$chksum_file";
    assert_script_run "md5sum -c --quiet $chksum_file", $nettout;
    assert_script_run "popd";
}


sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('BONE'));
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');
    # set timeout as 4800 as a temp workaround for slow nfs
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 4800);    # Timeout for HANA installation commands.

    select_serial_terminal;
    #select_console 'x11';

    # Transfer media.
    my $target = '/sapinst';    # Directory in SUT where install media will be copied token
    if (get_var 'ASSET_0') {
        # If the ASSET_0 variable is defined, the test will attempt to download
        # the HANA media from the factory/other directory of the openQA server.
        record_info "Dowloading using ASSET_0";
        download_hana_assets_from_server(target => $target, nettout => $tout);
    }
    elsif (get_required_var 'BONE') {
        # If not, the media will be retrieved from a remote server.
        record_info "Downloading using $proto";
        $self->copy_media($proto, $path, $tout, $target);
    }

    # install bin is used for installation, verify if it exists
    my $install_bin = '/sapinst/' . get_var('B1_INSTALL', "Packages.Linux/ServerComponents" . "/install");
    die "install is not in [$install_bin]. Set B1_INSTALL to the appropiate relative path. Example: Packages.Linux/ServerComponents/install" if (script_run "ls $install_bin");

    # Install B1
    # Download xml config
    my $b1_cfg = "bone.cfg";
    my $hostname = script_output 'hostname';
    my $local_url = "http://10.100.103.247:8000/";
    my $admin_id = "ndbadm";

    assert_script_run "curl -f -v " . $local_url . "$b1_cfg -o /tmp/$b1_cfg";
    #assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$b1_cfg -o /tmp/$b1_cfg";

    # change some default values
    file_content_replace("/tmp/$b1_cfg", '%SERVER%' => $hostname);
    file_content_replace("/tmp/$b1_cfg", '%INSTANCE%' => $instid);
    file_content_replace("/tmp/$b1_cfg", '%TENANT_DB%' => $sid);
    file_content_replace("/tmp/$b1_cfg", '%PASSWORD%' => $sles4sap::instance_password);
    file_content_replace("/tmp/$b1_cfg", '%ADMIN_ID%' => $admin_id);
    assert_script_run "$install_bin -i silent -f /tmp/$b1_cfg --debug", $tout;

    # Upload installations logs
    $self->upload_hana_install_log;
}

sub test_flags {
    return {fatal => 1};
}

1;
