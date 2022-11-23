# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Install glibc livepatch and run openposix testsuite
# Maintainer: Martin Doucha <mdoucha@suse.cz>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal;
use klp;
use LTP::utils;
use OpenQA::Test::RunArgs;

sub prepare_repo {
    my ($packname) = @_;
    my @repos = split(",", get_required_var('INCIDENT_REPO'));
    my @repo_names;

    install_klp_product;
    zypper_call('in libpulp0 libpulp-tools');

    while ((my ($i, $url)) = (each(@repos))) {
        push @repo_names, "ULP_$i";
        zypper_ar($url, name => $repo_names[$i]);
    }

    my $repo_args = join(' ', map({ "-r $_" } @repo_names));
    my $provides = script_output("zypper -n info --provides $repo_args $packname");
    my @versions = $provides =~ m/^\s*libc_([^_]+)_livepatch\d+\.so\(\)\([^)]+\)\s*$/gm;

    die "Package $packname contains no libc livepatches" unless scalar @versions;

    prepare_ltp_env;
    return \@versions;
}

sub run {
    my ($self, $tinfo) = @_;
    my ($glibc_versions, $run_id);
    my $packname = "glibc-livepatches";

    select_serial_terminal;

    if (!defined($tinfo)) {
        # First test round in the job, prepare environment
        $glibc_versions = prepare_repo($packname);
        $run_id = 0;
    } else {
        $glibc_versions = $tinfo->{glibc_versions};
        $run_id = $tinfo->{run_id};
        zypper_call("rm $packname");
    }

    # Schedule openposix tests and install the livepatch
    my $libver = $$glibc_versions[$run_id];
    record_info('glibc version', $libver);
    zypper_call("in --oldpackage glibc-$libver");
    schedule_tests('openposix', "_glibc-$libver");
    loadtest_kernel('ulp_threads', name => "ulp_threads_glibc-$libver");
    zypper_call("in $packname");

    # Run tests again with the next untested glibc version
    if ($run_id < $#$glibc_versions) {
        my $runargs = OpenQA::Test::RunArgs->new(run_id => $run_id + 1,
            glibc_versions => $glibc_versions);

        loadtest_kernel('ulp_openposix', run_args => $runargs);
    }
    else {
        shutdown_ltp;
    }
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
    };
}

=head1 Configuration

This test module is activated by LIBC_LIVEPATCH=1

=cut

1;
