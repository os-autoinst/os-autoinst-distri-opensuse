# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Trilinos smoke test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base qw(hpcbase hpc::utils), -signatures;
use testapi;
use utils;

sub run ($self) {
    zypper_call('in libtrilinos-gnu-openmpi3-hpc trilinos-gnu-openmpi3-hpc-devel');
    $self->relogin_root;

    if (script_run('module load gnu openmpi trilinos') != 0) {
        my $out_text = script_output('module load trilinos', proceed_on_failure => 1);
        if ($out_text =~ /Lmod has detected the following error/) {
            force_soft_failure "bsc#1200376: lmod cant load trilinos";
        }
    }
    script_run "module av";
    if (!script_run qq{IFS=\": \"; for i in \$LD_LIBRARY_PATH; do for j in \$i/*.so.*; do ldd \$j; done; done | grep \"not found\"}) {
        force_soft_failure "bsc#1200376: missing libs in \$LD_LIBRARY_PATH";
    }
}

1;
