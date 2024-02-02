# SUSE's SLES4SAP openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SAP ASE via command line using a response file. Both
# the installation media and the response file are supplied as openQA
# assets. Verify installation with sles4sap/ase_test.
#
# This test module expects the tarball with the installation files for SAP ASE
# in ASSET_0 and the gzipped response file in ASSET_1
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use Utils::Logging qw(save_and_upload_log);
use version_utils qw(is_sle);

=head2 prepare_system_for_ase

  $self->prepare_system_for_ase

Run some preparation commands in the system before SAP ASE's installation.
This includes setting kernel.randomize_va_space to the recommended value,
adding the hostname to /etc/hosts, creating a target directory where to
download the ASE installer and applying the SAP-ASE profile to the
system via saptune.

=cut

sub prepare_system_for_ase {
    my ($self, %args) = @_;
    $args{target} //= '/sapinst';
    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;
    $self->prepare_profile('SAP-ASE');
    # We need to ensure that the kernel parameter kernel.randomize_va_space is set to 0 SLES 11+
    assert_script_run 'sysctl kernel.randomize_va_space=0';
    record_info 'kernel.randomize_va_space', script_output('sysctl kernel.randomize_va_space', proceed_on_failure => 1);
    assert_script_run "mkdir -p $args{target}";
}

=head2 download_ase_assets

  my $installation_dir = $self->download_ase_assets()

Download SAP ASE installation tarball (.TGZ format) from ASSET_0 setting, and dowload
the response file require for installation (.GZ text format) from ASSET_1 setting.
Returns the directory that contains the unpacked installation files.

=cut

sub download_ase_assets {
    my ($self, %args) = @_;
    $args{target} //= '/sapinst';
    $args{timeout} //= 600;
    assert_script_run "pushd $args{target}";
    # Verify ASSET_0 and ASSET_1 are set
    get_required_var("ASSET_$_") for (0 .. 1);
    # Download assets into SUT
    record_info 'SAP ASE Installer', get_var('ASSET_0');
    my $ase_location = data_url('ASSET_0');
    assert_script_run "wget -O - $ase_location | tar -zxf -", timeout => $args{timeout};
    # SAP ASE installer extracts its contents in a directory that begins with 'ebf'
    # The following lines will attempt to find the directory name the files were extracted on
    my $instdir = script_output 'echo ":$(ls -d ebf* | tail -1):"';
    die "Could not determine the installer's path. Current contents of [$args{target}] are:\n" . script_output 'ls'
      unless ($instdir =~ /:([^:]+):/);
    $instdir = "$args{target}/$1";
    record_info 'Installer Directory', $instdir;
    assert_script_run 'popd';
    my $response_file_location = data_url('ASSET_1');
    assert_script_run "wget -O - $response_file_location | gunzip -c > " . $self->ASE_RESPONSE_FILE, timeout => $args{timeout};
    return $instdir;
}

sub run {
    my ($self) = @_;
    my $response_file = get_required_var('ASSET_1');    # Response file comes gzipped in ASSET_1
    $response_file =~ s/.gz$//;
    $self->ASE_RESPONSE_FILE($response_file);    # Set the response file name in the object instance

    select_serial_terminal;
    enter_cmd 'cd';    # Let's start in $HOME
    $self->prepare_system_for_ase;
    my $instdir = $self->download_ase_assets;
    file_content_replace($self->ASE_RESPONSE_FILE, '%PASSWORD%', $testapi::password);
    upload_logs $self->ASE_RESPONSE_FILE;
    assert_script_run "pushd $instdir";
    # In manual tests, it took ca. 35 minutes to install ASE, so expecting 1 hour to be enough
    assert_script_run './setup.bin -i silent -f $HOME/' . $self->ASE_RESPONSE_FILE, timeout => 3600;
    assert_script_run 'popd';
    $self->upload_ase_logs;
}

sub test_flags {
    return {fatal => 1};
}

1;
