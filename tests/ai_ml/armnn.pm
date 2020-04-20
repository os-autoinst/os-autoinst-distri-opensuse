# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This module install armnn and downloads
#   test programs, models, labels and images.
#   Then, it runs models with the images as inputs.
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub armnn_get_images {
    assert_script_run('mkdir -p armnn/data');
    assert_script_run('cp ~/data/ai_ml/images/{Cat,Dog,shark}.jpg armnn/data/');
}

sub armnn_tf_lite_test_prepare {
    # Only the *.tflite files are needed, but more files are in the archives
    assert_script_run('mkdir -p armnn/models');
    assert_script_run('pushd armnn/models');
    assert_script_run('tar xzf ~/data/ai_ml/models/mnasnet_1.3_224_09_07_2018.tgz');
    assert_script_run('mv mnasnet_*/* .');
    # inception_v3_quant.tgz is too big to be stored on github, so download it here
    assert_script_run('wget http://download.tensorflow.org/models/tflite_11_05_08/inception_v3_quant.tgz -O ~/data/ai_ml/models/inception_v3_quant.tgz');
    assert_script_run('tar xzf ~/data/ai_ml/models/inception_v3_quant.tgz');
    assert_script_run('tar xzf ~/data/ai_ml/models/mobilenet_v1_1.0_224_quant.tgz');
    assert_script_run('tar xzf ~/data/ai_ml/models/mobilenet_v2_1.0_224_quant.tgz');
    assert_script_run('popd');
}

sub armnn_tf_lite_test_run {
    my %opts = @_;
    my $backend_opt;
    $backend_opt = "-c $opts{backend}" if $opts{backend};    # Can be CpuRef, CpuAcc, GpuAcc, ...

    # assert_script_run("TfLiteInceptionV3Quantized-Armnn --data-dir=armnn/data --model-dir=armnn/models $backend_opt"); # Broken with current Cat.jpg image
    assert_script_run("TfLiteMnasNet-Armnn --data-dir=armnn/data --model-dir=armnn/models $backend_opt");
    # assert_script_run("TfLiteMobilenetQuantized-Armnn --data-dir=armnn/data --model-dir=armnn/models $backend_opt"); # Broken with current Dog.jpg image
    assert_script_run("TfLiteMobilenetV2Quantized-Armnn --data-dir=armnn/data --model-dir=armnn/models $backend_opt");
}

sub run {
    my ($self)         = @_;
    my $armnn_backends = get_var("ARMNN_BACKENDS");          # Comma-separated list of armnn backends to test explicitly. E.g "CpuAcc,GpuAcc"

    $self->select_serial_terminal;
    zypper_call $armnn_backends =~ /GpuAcc/ ? 'in armnn-opencl' : 'in armnn';

    select_console 'user-console';

    # Get images used for tests
    armnn_get_images;

    # Test TensorFlow Lite backend
    armnn_tf_lite_test_prepare;
    # Run with default backend
    armnn_tf_lite_test_run;
    # Run with explicit backend, if requested
    armnn_tf_lite_test_run(backend => $_) for split(/,/, $armnn_backends);
}

1;
