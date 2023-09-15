# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Verify latest gnu-compilers-hpc installation
#
# Test later toolchain versions that are made available for SLE.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase), -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Logging qw(export_logs);

sub run ($self) {
    select_serial_terminal();
    my $version = get_required_var('GNU_COMPILERS_HPC_VERSION');
    zypper_call("in gnu$version-compilers-hpc");
    type_string('pkill -u root', lf => 1);
    $self->{serial_term_prompt} = '# ';
    serial_terminal::login('root', $self->{serial_term_prompt});

    assert_script_run qq{module av | grep gnu/$version};
    assert_script_run 'module load gnu';
    assert_script_run qq{env |grep "MODULEPATH=/usr/share/lmod/moduledeps/gnu-$version"};
    if (zypper_call("in gnu$version-compilers-hpc-devel", exitcode => [107]) == 107) {
        record_soft_failure 'bsc#1212351 Type in posttrans script for the non-base Compiler Version cause Script to fail';
    }
    assert_script_run 'module load gnu';
    assert_script_run qq{env |grep "PATH=/usr/lib/hpc/compiler/gnu/$version/bin"};
    assert_script_run qq{gcc --version | grep $version};

}

sub post_fail_hook ($self) {
    export_logs();
}

1;
