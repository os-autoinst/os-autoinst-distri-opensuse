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
    my $version = get_var('GNU_COMPILERS_HPC_VERSION', '');
    my $expected_version = $version ? $version : '7';

    zypper_call("in gnu$version-compilers-hpc");
    type_string('pkill -u root', lf => 1);
    $self->{serial_term_prompt} = '# ';
    serial_terminal::login('root', $self->{serial_term_prompt});

    assert_script_run qq{module av | grep gnu/$expected_version};
    assert_script_run 'module load gnu';
    assert_script_run qq{env |grep "MODULEPATH=/usr/share/lmod/moduledeps/gnu-$expected_version"};
    zypper_call("in gnu$version-compilers-hpc-devel");
    assert_script_run 'module load gnu';
    assert_script_run qq{env |grep "PATH=/usr/lib/hpc/compiler/gnu/$expected_version/bin"};
    assert_script_run qq{gcc --version | grep $expected_version};
}

sub post_fail_hook ($self) {
    export_logs();
}

1;
