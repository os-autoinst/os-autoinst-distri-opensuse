# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: python-cairo tests
# - install python-cairo package
# - import pycairo script and sample svg file
# - execute pycairo script and generate svg file
# - Compare the generated svg file with expected one
#
# Maintainer: QE-Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle is_leap);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Make sure pycairo python module is installed
    zypper_call "in python3 python3-pycairo";

    # Import pycairo script and sample svg file
    assert_script_run("curl -O " . data_url("python/pycairo_sample.py"));

    my $sample_svg = (is_leap('<15.6') || is_sle('<15-SP6')) ? "pycairo_sample.svg" : "pycairo_sample_new.svg";
    assert_script_run("curl -O " . data_url("python/$sample_svg"));

    # Execute pycairo script and generate the svg file
    assert_script_run("python3 pycairo_sample.py");

    # Compare generated svg file with the expected one
    assert_script_run("diff $sample_svg  pycairo_generated.svg");

    $self->cleanup();
}

sub post_fail_hook {
    my $self = shift;
    upload_logs("pycairo_generated.svg");
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup {
    script_run("rm -f pycairo_sample.py pycairo_sample.svg pycairo_sample_tumbleweed.svg pycairo_generated.svg");
}

1;
