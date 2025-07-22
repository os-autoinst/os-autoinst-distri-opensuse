# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: libjpeg_turbo
# Summary: Check libjpeg_turbo version
# - Test should test on sle15sp6, see https://jira.suse.com/browse/PED-4889
# - Check libjpeg-turbo version is higher than 2.1.1
# - Do functional check with jpegtran command
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use utils qw(zypper_call upload_y2logs);
use registration qw(add_suseconnect_product get_addon_fullname);
use registration qw(add_suseconnect_product is_phub_ready);

sub run {
    select_serial_terminal;

    # Package 'libjpeg-turbo' requires PackageHub is available
    return if (!is_phub_ready() && is_sle);

    # Package ImageMagick requires Desktop-Applications is available
    add_suseconnect_product(get_addon_fullname('desktop')) if is_sle('=15-SP7');

    # Install libjpeg-turbo package
    zypper_call("install libjpeg-turbo");
    my $install_version = script_output('rpm -q libjpeg-turbo --qf %{version}');
    record_info("libjpeg-turbo version", $install_version);
    die("libjpeg-turbo version was not updated") if (package_version_cmp($install_version, '2.1.1') <= 0);

    # Use jpegtran command to rotate image
    zypper_call("install ImageMagick");
    my $image = 'lizard.jpeg';
    assert_script_run "wget --quiet " . data_url("imagemagick/$image");
    my $size = script_output("identify -format %wx%h $image");
    record_info('Old width x height: ', $size);
    my $image_rot = 'lizard_rot.jpeg';
    # Rotate an image 90 degrees clockwise, discarding any unrotatable edge pixels
    assert_script_run("jpegtran -rot 90 -trim $image > $image_rot");
    my $rot_size = script_output("identify -format %wx%h $image_rot");
    record_info('New width x height: ', $rot_size);
    die("Rotate image failed") if ($size == $rot_size);
}

sub post_fail_hook {
    my ($self) = shift;
    upload_y2logs;
    $self->SUPER::post_fail_hook;
}

1;
