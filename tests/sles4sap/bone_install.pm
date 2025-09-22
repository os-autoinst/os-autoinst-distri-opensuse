# SUSE's SLES4SAP openQA tests
#
# Copyright 2019-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SAP Business One via command line.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils qw(file_content_replace zypper_call);
use Utils::Systemd 'systemctl';
use version_utils qw(package_version_cmp is_sle);
use POSIX 'ceil';
use Utils::Logging 'save_and_upload_log';


sub b1_workaround_install {
    my ($install_bin, $b1_cfg, $tout) = @_;
    assert_script_run "curl -f -v -O " . autoinst_url . "/data/sles4sap/b1_workaround.tar.gz";
    assert_script_run "curl -f -v -O " . autoinst_url . "/data/sles4sap/b1_installer.sh";
    assert_script_run "tar xvf b1_workaround.tar.gz -C /tmp";
    assert_script_run "chmod +x /tmp/*.sh";
    assert_script_run "chmod +x b1_installer.sh";
    assert_script_run "./b1_installer.sh $install_bin $b1_cfg", $tout;
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('BONE'));
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');
    # set timeout as 4800 as a temp workaround for slow nfs
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 4800);    # Timeout for HANA installation commands.

    select_serial_terminal;

    # Transfer media.
    my $target = '/sapinst';    # Directory in SUT where install media will be copied token
    if (get_var('ASSET_0')) {
        # If the ASSET_0 variable is defined, the test will attempt to download
        # the HANA media from the factory/other directory of the openQA server.
        record_info "Dowloading using ASSET_0";
        $self->download_hana_assets_from_server(target => $target, nettout => $tout);
    }
    elsif (get_required_var 'BONE') {
        # If not, the media will be retrieved from a remote server.
        record_info "Downloading using $proto";
        $self->copy_media($proto, $path, $tout, $target);
    }

    # install bin is used for installation, verify if it exists
    my $install_bin = join('/', $target, get_var('B1_INSTALL', 'B1/Packages.Linux/ServerComponents/install'));
    die "install is not in [$install_bin]. Set B1_INSTALL to the appropiate relative path. Example: Packages.Linux/ServerComponents/install" if (script_run "ls $install_bin");

    # Install B1
    # Download xml config
    my $b1_cfg = "bone.cfg";
    my $hostname = script_output 'hostname';
    my $admin_id = "ndbadm";

    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$b1_cfg -o /tmp/$b1_cfg";

    # change some default values
    file_content_replace("/tmp/$b1_cfg", '%SERVER%' => $hostname, '%INSTANCE%' => $instid, '%TENANT_DB%' => $sid, '%PASSWORD%' => $sles4sap::instance_password);

    # initial workaround for 15-SP7 and b1 installer 2502
    $self->b1_workaround_os_version;

    # workaround for broken b1 installer and curl 8.14
    my $package_version = script_output "rpm -q --qf 'curlver=%{VERSION}\n' curl";
    $package_version =~ /curlver=([\d\.]+)/;
    $package_version = $1;
    die 'Could not determine curl version' unless ($package_version);
    if (package_version_cmp($package_version, '8.14.1') <= 0) {
        record_soft_failure "jsc#TEAM-10632 - Workaround for Business One due to bsc#1246964 / libcurl update";
        # place workaround for curl and b0rken b1 installer
        b1_workaround_install($install_bin, $b1_cfg, $tout);
    } else {
        # Normal install
        assert_script_run "$install_bin -i silent -f /tmp/$b1_cfg --debug", $tout;
    }

    # Upload installations logs
    $self->upload_hana_install_log;
}

sub test_flags {
    return {fatal => 1};
}

1;
