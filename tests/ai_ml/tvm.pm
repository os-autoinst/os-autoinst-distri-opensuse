# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: This module install and test tvm
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $tvm_tvmc_tune = get_var('TVM_TVMC_TUNE');

    $self->select_serial_terminal;

    zypper_call 'in python3-tvm tvmc python3-onnx python3-Pillow python3-pytest python3-tornado gcc-c++';

    select_console 'user-console';
    record_info('AutoTVM');
    # From https://tvm.apache.org/docs/tutorials/autotvm/tune_simple_template.html
    assert_script_run('curl -L -O https://tvm.apache.org/docs/_downloads/0bb862dbb3a4c434477f93fe2c147fbb/tune_simple_template.py');
    assert_script_run('python3 tune_simple_template.py');

    # https://tvm.apache.org/docs/tutorials/get_started/tvmc_command_line_driver.html
    # TVMC supports models created with Keras, ONNX, TensorFlow, TFLite and Torch. Use onnx model here.
    record_info('tvmc - no tune');
    assert_script_run('curl -L -O https://github.com/onnx/models/raw/master/vision/classification/resnet/model/resnet50-v2-7.onnx');
    assert_script_run('curl -L -O https://tvm.apache.org/docs/_downloads/18fb1ab3ed0a0c9f304520f2beaf4fd6/tvmc_command_line_driver.py');

    assert_script_run('tvmc compile --target "llvm" --output compiled_module.tar resnet50-v2-7.onnx', timeout => 600);
    assert_script_run('python3 tvmc_command_line_driver.py');
    assert_script_run('tvmc run --inputs imagenet_cat.npz --output predictions.npz compiled_module.tar');
    assert_script_run('python3 ~/data/ai_ml/tvm/post_processing.py');

    if ($tvm_tvmc_tune) {
        record_info('tvmc - tuned');
        assert_script_run('tvmc tune --target "llvm" --output autotuner_records.json resnet50-v2-7.onnx',                  timeout => 600);
        assert_script_run('tvmc compile --tuning-records --target "llvm" --output compiled_module.tar resnet50-v2-7.onnx', timeout => 600);
        assert_script_run('python3 tvmc_command_line_driver.py');
        assert_script_run('tvmc run --inputs imagenet_cat.npz --output predictions.npz compiled_module.tar');
        assert_script_run('python3 ~/data/ai_ml/tvm/post_processing.py');
    }
}

1;
