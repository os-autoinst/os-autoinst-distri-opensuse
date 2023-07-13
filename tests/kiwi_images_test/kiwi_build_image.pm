# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform a Kiwi test to build a qcow2 image locally.
# Firstly, install Kiwi-ng and copy the Kiwi XML file from the data
# folder to the /tmp directory.
# Execute the Kiwi-ng command to build the KVM and Xen image locally.
# Upload the locally created qcow2 image for further testing.
# Maintainer: QE Core <qe-core@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

my $testdir = '/tmp';

sub run {
    my ($self) = @_;
    my $build = get_var("BUILD");
    my $version = get_var("VERSION");
    $self->select_serial_terminal;
    # Install KIWI-NG
    zypper_call 'in python3-kiwi';
    assert_script_run("mkdir -p  $testdir");
    # Copy the Kiwi XML description file from the data folder for building the
    # Kiwi image locally
    assert_script_run("curl -v -o $testdir/appliance.kiwi " . data_url("kiwi/appliance.kiwi"));
    assert_script_run("curl -v -o $testdir/config.sh " . data_url("kiwi/config.sh"));
    assert_script_run("sed -ie 's/SLE-version/$version/' $testdir/appliance.kiwi");
    # Execute the Kiwi-ng command to build the KVM and Xen system image
    assert_script_run("kiwi-ng --profile kvm-and-xen  system build  --description $testdir  --target-dir /tmp/", timeout => 1200);
    # Verify the built qcow2 image filename in the /tmp folder and rename the file with the proper build number,
    # considering that the Kiwi NG XML requires a mandatory image version in the format of Major.Minor.Releases,
    # while the SLE Build may have different requirements.
    validate_script_output("ls -l /tmp", sub { m/SLES$version-kiwi.x86_64-1.1.0.qcow2/ });
    assert_script_run("qemu-img convert -c -O qcow2 /tmp/SLES$version-kiwi.x86_64-1.1.0.qcow2 /tmp/SLES$version-kiwi.x86_64-$build.qcow2;sync");
    upload_asset("/tmp/SLES$version-kiwi.x86_64-$build.qcow2");
}

1;
