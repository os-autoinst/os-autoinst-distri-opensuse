# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module install tensorflow2-lite and downloads
#   a test program in python, a model, labels and an image.
#   Then, it runs the model with the image as input.
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_opensuse is_leap);

sub run {
    select_serial_terminal;
    # Install required software
    my $ret;
    if (is_leap) {
        zypper_call('in tensorflow2-lite python3-Pillow python3-numpy');
        $ret = zypper_call('in  python3-tensorflow ', exitcode => [0, 4, 104]);
    } else {
        zypper_call('in tensorflow-lite python3-Pillow python3-numpy');
    }

    select_console('user-console');
    # Perform tests in a separate folder
    assert_script_run('mkdir tflite2_tests && pushd tflite2_tests');

    # Extract model and labels
    assert_script_run('unzip ~/data/ai_ml/models/mobilenet_v1_1.0_224_quant_and_labels.zip');

    my $result = script_output("python3 ~/data/ai_ml/label_image_tflite.py --image ~/data/ai_ml/images/White_shark.jpg --model_file mobilenet_v1_1.0_224_quant.tflite --label_file labels_mobilenet_quant_v1_224.txt | tee /dev/$serialdev | head -n1", proceed_on_failure => 1);
    record_info("TEST LOG", "$result");

    if ($result !~ /great white shark/) {
        if ($ret == 4 && is_opensuse) {
            record_soft_failure("boo#1199429 nothing provides 'libprotobuf.so.30()(64bit)' needed by the to be installed tensorflow2");
        } elsif ($ret == 104 && is_leap) {
            record_soft_failure("boo#1199330 package python3-tensorflow is not found");
        } else {
            die("Failed to match the result 'great white shark' after the python test run");
        }

    }

    # Clean-up
    assert_script_run('popd && rm -rf tflite2_tests');
}

1;
