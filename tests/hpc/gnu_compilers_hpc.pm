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
use version_utils;
use Utils::Logging qw(export_logs);

sub run ($self) {
    select_serial_terminal();
    my $version = get_var('GNU_COMPILERS_HPC_VERSION', '');
    # When non-versioned gnu_compilers_hpc is installed
    # The default gcc version for SLE12 is 4.8
    # Since SLE15 the default is gcc7
    my $default_version = check_version('>=15-SP0', get_var('VERSION'), qr/\d{2}(?:-sp\d)?/) ? '7' : '4.8';
    my $expected_version = $version ? $version : $default_version;

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
    assert_script_run qq{gcc --version | grep -E "^gcc \\(SUSE Linux\\) $expected_version\\.[0-9]*"};
}

sub post_fail_hook ($self) {
    export_logs();
}

1;
