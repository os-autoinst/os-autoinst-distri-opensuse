# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module install and test tvm
# Maintainer: Guillaume GARDET <guillaume@opensuse.org>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_tumbleweed';

sub run {
    my $tvm_tvmc_tune = get_var('TVM_TVMC_TUNE');

    select_serial_terminal;

    # Current TVM does not support python 3.10, the default python3 in Tumbleweed, so force python 3.8
    my $python_interpreter = is_tumbleweed() ? 'python3.8' : 'python3';
    my $pythonsuffix = is_tumbleweed() ? '38' : '3';

    zypper_call "in tvmc python$pythonsuffix-pytest python$pythonsuffix-tornado gcc-c++";

    select_console 'user-console';
    record_info('AutoTVM');
    assert_script_run('curl -L -O https://github.com/apache/tvm/raw/72c9a51687c5882c5bd13d718a69892d45b5cc4b/tutorials/autotvm/tune_simple_template.py');
    assert_script_run("$python_interpreter tune_simple_template.py");

    # https://tvm.apache.org/docs/tutorials/get_started/tvmc_command_line_driver.html
    # TVMC supports models created with Keras, ONNX, TensorFlow, TFLite and Torch. Use onnx model here.
    record_info('tvmc - no tune');
    assert_script_run('curl -L -O https://media.githubusercontent.com/media/onnx/models/main/vision/classification/resnet/model/resnet50-v2-7.onnx');
    assert_script_run('curl -L -O https://github.com/apache/tvm/raw/b7b69a2d1dbfe7a9cd04ddab2e60f33654419d58/tutorials/get_started/tvmc_command_line_driver.py');

    assert_script_run('tvmc compile --target "llvm" --input-shapes "data:[1,3,224,224]" --output compiled_module.tar resnet50-v2-7.onnx', timeout => 600);
    assert_script_run("$python_interpreter tvmc_command_line_driver.py");
    assert_script_run('tvmc run --inputs imagenet_cat.npz --output predictions.npz compiled_module.tar');
    assert_script_run("$python_interpreter ~/data/ai_ml/tvm/post_processing.py");

    if ($tvm_tvmc_tune) {
        record_info('tvmc - tuned');
        assert_script_run('tvmc tune --target "llvm" --output autotuner_records.json resnet50-v2-7.onnx', timeout => 600);
        assert_script_run('tvmc compile --tuning-records --target "llvm" --output compiled_module.tar resnet50-v2-7.onnx', timeout => 600);
        assert_script_run("$python_interpreter tvmc_command_line_driver.py");
        assert_script_run('tvmc run --inputs imagenet_cat.npz --output predictions.npz compiled_module.tar');
        assert_script_run("$python_interpreter ~/data/ai_ml/tvm/post_processing.py");
    }
}

1;
