# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: exiv2 wget
# Summary: Add exiv2 tests
#    Checks exif metadata from given image.
#    Checks exiv2 functionalities like renaming and creating preview image from metadata.
#
#    The examined images were created for this test purpose only.
#
# Maintainer: João Walter Bruno Filho <bfilho@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub exiv2_info_test {

    # Partial excerpts from the exiv2 output from test image file
    my %exif_expected_output = (
        expected_output_exiv2_info_filename => "File name       : test.jpg",
        expected_output_exiv2_info_size => "File size       : 26737 Bytes",
        expected_output_exiv2_info_maker => "Camera make     : Manufacturer",
        expected_output_exiv2_info_model => "Camera model    : Test Model",
        expected_output_exiv2_info_aperture => "Aperture        : F1.1",
        expected_output_exiv2_info_iso => "ISO speed       : 100",
        expected_output_exiv2_info_metering => "Metering mode   : Multi-spot",
        expected_output_exiv2_info_copyright => "Copyright       : SUSE Inc",
        expected_output_exiv2_info_comment => "Exif comment    : (charset=Ascii )?Test caption label",
    );

    # Partial excerpts from the exiv2 -pt output from test image file
    my %exif_expected_ptoutput = (
        expected_output_exiv2_ptinfo_sw => "Exif.Image.ProcessingSoftware                Ascii      14  digiKam-5.5.0",
        expected_output_exiv2_ptinfo_dn => "Exif.Image.DocumentName                      Ascii      20  SUSE_EXIV2_TESTFILE",
        expected_output_exiv2_ptinfo_description => "Exif.Image.ImageDescription                  Ascii      19  Test caption label",
        expected_output_exiv2_ptinfo_data => "Exif.Image.DateTime                          Ascii      20  2019:02:01 15:44:21",
        expected_output_exiv2_ptinfo_artist => "Exif.Image.Artist                            Ascii       5  SUSE",
        expected_output_exiv2_ptinfo_copyright => "Exif.Image.Copyright                         Ascii       9  SUSE Inc",
        expected_output_exiv2_ptinfo_exiftag => "Exif.Image.ExifTag                           Long        1  288",
        expected_output_exiv2_ptinfo_fnumber => "Exif.Photo.FNumber                           SRational   1  F1.1",
        expected_output_exiv2_ptinfo_brightness => "Exif.Photo.BrightnessValue                   SRational   1  1.1",
        expected_output_exiv2_ptinfo_max_aperture => "Exif.Photo.MaxApertureValue                  SRational   1  F1.3",
        expected_output_exiv2_ptinfo_lightsource => "Exif.Photo.LightSource                       SLong       1  Daylight",
        expected_output_exiv2_ptinfo_focal_length => "Exif.Photo.FocalLength                       SRational   1  50.0 mm",
        expected_output_exiv2_ptinfo_user_comment => "Exif.Photo.UserComment                       Undefined  26  (charset=Ascii )?Test caption label",
        expected_output_exiv2_ptinfo_subject_distance => "Exif.Photo.SubjectDistanceRange              SLong       1  Close view",
        expected_output_exiv2_ptinfo_jpeg_format => "Exif.Thumbnail.JPEGInterchangeFormat         Long        1  818",
    );

    my $output_exiv2_info = script_output "exiv2 test.jpg";
    my @exif_infos = keys %exif_expected_output;

    #checks for the expected output from exiv2 metadata based on previous capture
    for my $exif_info (@exif_infos) {
        die "Missing exiv2 info. Expected: /$exif_expected_output{$exif_info}/ \nGot: /$output_exiv2_info/"
          unless $output_exiv2_info =~ m/$exif_expected_output{$exif_info}/;
    }

    my @exif_ptinfos = keys %exif_expected_ptoutput;
    my $output_exiv2_ptinfo = script_output "exiv2 -pt test.jpg";

    #checks for the expected output from exiv2 -pt command based on previous capture
    for my $exif_ptinfo (@exif_ptinfos) {
        die "Missing exiv2 info. Expected: /$exif_expected_ptoutput{$exif_ptinfo}/ \nGot: /$output_exiv2_ptinfo/"
          unless $output_exiv2_ptinfo =~ m/$exif_expected_ptoutput{$exif_ptinfo}/;
    }
}

sub run {
    select_console "x11";
    x11_start_program('xterm');

    #prepare
    become_root;
    quit_packagekit;
    zypper_call "in exiv2";

    #Get assets to local directory
    assert_script_run "wget --quiet " . data_url('exiv2/test.jpg') . " -O test.jpg";

    #run exiv2 info metadata check tests
    exiv2_info_test;

    #check exiv2 rename feature, which rename files to image's create timestamp info
    #from metadata
    assert_script_run "exiv2 rename test.jpg";
    assert_script_run "ls -ld 20190201_154421.jpg";
    script_run "eog 20190201_154421.jpg", 0;
    assert_screen "exiv2_rename_test";
    send_key 'alt-f4';
    wait_still_screen(1);

    #check exiv2 preview feature, which extracts a image preview from the file.
    assert_script_run "exiv2 -ep1 20190201_154421.jpg";
    assert_script_run "ls -ld 20190201_154421-preview1.jpg";
    script_run "eog 20190201_154421-preview1.jpg", 0;
    assert_screen "exiv2_test_preview";
    send_key 'alt-f4';
    wait_still_screen(1);

    # clean-up
    assert_script_run "rm 20190201_154421.jpg";
    assert_script_run "rm 20190201_154421-preview1.jpg";
    send_key "alt-f4";
}

1;
