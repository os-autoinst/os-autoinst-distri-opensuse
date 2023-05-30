# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide functionality for hpc tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package hpc::utils;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';
use version;

sub get_mpi() {
    my $mpi = get_required_var('MPI');

    if ($mpi eq 'openmpi3') {
        if (is_sle('<15')) {
            $mpi = 'openmpi';
        } elsif (is_sle('<15-SP2')) {
            $mpi = 'openmpi2';
        }
    }

    return $mpi;
}

=head2 get_mpi_src

 get_mpi_src();

Returns the source code which is used based on B<HPC_LIB> job variable. The variable indicates the HPC library
which the mpi use to compile the source code. But the variable can be any indicator to select the requisite
source code that test should use.

Make sure that the source code matches with the correct compiler.
if the variable is not set, one of the other MPI implementations
will be used(mpich, openmpi, mvapich2).

Returns an array with the mpi compiler and the source code located in /data/hpc

=cut

sub get_mpi_src {
    my $libvar = get_var('HPC_LIB', '');
    record_info "WHAT", "$libvar";
    return ('mpicc', 'simple_mpi.c') if ($libvar eq '');
    return ('mpic++', 'sample_cplusplus.cpp') if ($libvar eq 'c++');
    return ('mpic++', 'sample_boost.cpp') if ($libvar eq 'boost');
    return ('', 'sample_scipy.py') if ($libvar eq 'scipy');
    return ('mpicc', 'papi_hw_info.c') if (get_var('HPC_LIB') eq 'papi');
    return ('mpicc', 'test_cblas_dgemm.c') if (get_var('HPC_LIB') eq 'openblas');
}

=head2 relogin_root

 relogin_root();

This sub logouts the root user and relogins him from terminal.
Useful to rerun configuration scripts after some changes

=cut

sub relogin_root {
    my $self = shift;
    record_info 'relogin', 'user needs to logout and login back to trigger scripts which set env variales and others. Switch to root-console';
    select_console "root-console";
    type_string('pkill -u root', lf => 1);
    record_info "pkill done";
    $self->wait_boot_textmode(ready_time => 180);
    select_serial_terminal();

    # Make sure that sshd is up. (TODO: investigate)
    systemctl('restart sshd');
}

=head2 setup_scientific_module

 setup_scientific_module();

Installs the various scientific HPC libraries and prepares the environment for use
L<https://documentation.suse.com/sle-hpc/15-SP3/single-html/hpc-guide/#sec-compute-lib>

When subroutine returns immediately returns 1 to indicate that no relogin has occurred.

=cut

sub setup_scientific_module {
    my ($self) = @_;
    return 1 unless get_var('HPC_LIB', '');
    my $mpi = get_required_var('MPI');
    my $lib = get_var('HPC_LIB', '');
    if ($lib eq 'scipy') {
        # $mpi-gnu-hpc-devel will be installed on compute nodes
        # which is required to compile the mpi4py.
        # This seems is not be shared by NFS
        # If you have a better idea let me know.
        zypper_call("in python3-scipy-gnu-hpc python3-devel $mpi-gnu-hpc-devel");

        # Make sure that env is updated. This will run scripts like 'source /usr/share/lmod/lmod/init/bash'
        $self->relogin_root;
        my $mpi2load = ($mpi =~ /openmpi2|openmpi3|openmpi4/) ? 'openmpi' : $mpi;
        assert_script_run "module load gnu $mpi2load python3-scipy";
        assert_script_run("env MPICC=mpicc python3 -m pip install mpi4py", timeout => 1200);
    }
    if ($lib eq 'papi') {
        zypper_call("in papi-hpc papi-hpc-devel");
        $self->relogin_root;
        assert_script_run('module load gnu $lib');
    }
    if ($lib eq 'openblas') {
        zypper_call("in libopenblas-gnu-hpc libopenblas-gnu-hpc-devel");
        $self->relogin_root;
        assert_script_run("module load gnu $mpi $lib");
    }
    return 0;
}

=head2 compare_mpi_versions

 compare_mpi_versions($package_name, $package_version, $another_package_version);

Given an HPC package, compare C<package_version> against C<another_package_version>.
The default behavior is to compare any given C<another_package_version> with the
installed version. In that case C<package_version> is determined in runtime.

=begin perl
 self->compare_mpi_versions("openmpi3-gnu-hpc", undef, '3.1.6-150500.11.3'));
=end perl

=for comment
C<package_name> can be undef. This it will compare just two given version

=for comment
Version format <mpi_version>-<hpc_module_vesrion>
=begin perl
 self->compare_mpi_versions(undef, $versionA, '3.1.6-150500.11.3'));
=end perl

It checks first if the package version is bigger than C<another_package_version> and
then compares its HPC versions. Returns I<true> bool when C<package_version> is bigger
than C<another_package_version>.

=cut

sub compare_mpi_versions {
    my ($self, $package_name, $v1, $v2) = @_;
    my $installed_version;
    if ($package_name) {
        script_run("zypper se -i $package_name") == 0 || die "package is not installed";
        $installed_version = script_output("zypper -q info $package_name | grep Version | awk '{ print \$3 }'");
    }
    $v1 ||= $installed_version || die "missing parameter: mpi package version";
    $v2 ||= die "missing parameter: mpi package version";
    my $mpi_version_pattern = qr/^(\d{1,2}\.\d{1,2}\.\d{1,2})-(\d+.\d{1,2}\.\d{1,2})/;
    my @expected_version = $v1 =~ $mpi_version_pattern;
    my @any_version = $v2 =~ $mpi_version_pattern;
    return (version->parse($expected_version[0]) >= version->parse($any_version[0])) || (version->parse($expected_version[1]) >= version->parse($any_version[1])); }

1;
