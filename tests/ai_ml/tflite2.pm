# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This module install tensorflow2-lite and downloads
#   a test program in python, a model, labels and an image.
#   Then, it runs the model with the image as input.
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    # Install required software
    zypper_call('in tensorflow2-lite python3-Pillow');

    select_console('user-console');
    # Perform tests in a separate folder
    assert_script_run('mkdir tflite2_tests && pushd tflite2_tests');

    # Extract model and labels
    assert_script_run('unzip ~/data/ai_ml/models/mobilenet_v1_1.0_224_quant_and_labels.zip');

    # Run the test
    assert_script_run("python3 ~/data/ai_ml/label_image.py --image ~/data/ai_ml/images/White_shark.jpg --model_file mobilenet_v1_1.0_224_quant.tflite --label_file labels_mobilenet_quant_v1_224.txt | tee /dev/$serialdev | head -n1", sub { m/great white shark$/ });

    # Clean-up
    assert_script_run('popd && rm -rf tflite2_tests');
}

1;
