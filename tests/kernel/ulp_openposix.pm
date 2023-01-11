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
use qam;
use LTP::utils;
use OpenQA::Test::RunArgs;

sub prepare_repo {
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repo = get_required_var('INCIDENT_REPO');
    my @repos = split(",", $repo);
    my @repo_names;
    my $packname;

    install_klp_product;
    zypper_call('in libpulp0 libpulp-tools');

    while ((my ($i, $url)) = (each(@repos))) {
        push @repo_names, "ULP_$i";
        zypper_ar($url, name => $repo_names[$i]);
    }

    my $repo_args = join(' ', map({ "-r $_" } @repo_names));
    my $packlist = zypper_search("-st package $repo_args");

    if (grep { $$_{name} eq 'glibc-livepatches' } @$packlist) {
        record_info('Livepatch tests', "Incident $incident_id contains userspace livepatches.");
        $packname = 'glibc-livepatches';
    }
    elsif (grep { $$_{name} eq 'libpulp0' || $$_{name} eq 'libpulp-tools' } @$packlist) {
        record_info('Tools tests', "Incident $incident_id contains livepatching tools.");

        my $patches = get_patches($incident_id, $repo);

        die "Patch isn't needed" unless $patches;
        $packname = 'openposix-livepatches';
        $repo_args = '';

        # Install the libpulp/tools update before running tests
        zypper_call("in -l -t patch $patches", exitcode => [0, 102, 103],
            log => 'zypper.log', timeout => 1400);
    }
    else {
        # Incident has no userspace livepatch related packages, nothing to do
        record_info('Exit', "Incident $incident_id contains no userspace livepatching related packages. Nothing to test.");
        return undef;
    }

    my $provides = script_output("zypper -n info --provides $repo_args $packname");
    my @versions = $provides =~ m/^\s*libc_([^_]+)_livepatch\d+\.so\(\)\([^)]+\)\s*$/gm;

    die "Package $packname contains no libc livepatches"
      unless scalar @versions;

    prepare_ltp_env;
    return OpenQA::Test::RunArgs->new(run_id => 0,
        glibc_versions => \@versions, packname => $packname);
}

sub run {
    my ($self, $tinfo) = @_;

    select_serial_terminal;

    if (!defined($tinfo)) {
        # First test round in the job, prepare environment
        $tinfo = prepare_repo();

        # Incident has no userspace livepatch related packages, nothing to do
        return if not $tinfo;
    } else {
        zypper_call("rm " . $tinfo->{packname});
    }

    # Schedule openposix tests and install the livepatch
    my $libver = $tinfo->{glibc_versions}[$tinfo->{run_id}];
    record_info('glibc version', $libver);
    zypper_call("in --oldpackage glibc-$libver");
    schedule_tests('openposix', "_glibc-$libver");
    loadtest_kernel('ulp_threads', name => "ulp_threads_glibc-$libver");
    zypper_call("in " . $tinfo->{packname});

    # Run tests again with the next untested glibc version
    if ($tinfo->{run_id} < $#{$tinfo->{glibc_versions}}) {
        my $runargs = OpenQA::Test::RunArgs->new(run_id => $tinfo->{run_id} + 1,
            glibc_versions => $tinfo->{glibc_versions},
            packname => $tinfo->{packname});

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
