# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test openssl-3-livepatches by iterating over supported openssl versions
# Maintainer: <qe-core@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal;
use klp;
use qam;
use version_utils;
use package_utils;
use LTP::utils;
use OpenQA::Test::RunArgs;

# Define global testing parameters
my $openssl_ver = get_var('OPENSSL_LP_VERSION', '3');
my ($packname, $libpackage, $command, $legacy_pkg_suffix);

if ($openssl_ver eq '1_1') {
    $packname = 'openssl-1_1-livepatches';
    $libpackage = 'libopenssl1_1';
    $command = '/usr/bin/openssl-1_1';
    $legacy_pkg_suffix = 'openssl-1_1';
} else {
    $packname = 'openssl-3-livepatches';
    $libpackage = 'libopenssl3';
    $command = 'openssl';
    $legacy_pkg_suffix = 'openssl-3';
}

sub setup_openssl_test {
    # Ensure libpulp tools are installed
    install_klp_product if is_sle('<16');
    install_package('libpulp0 libpulp-tools libpulp-load-default');

    # Get all available openssl-3 versions from repositories
    my $openssl_versions_rpm = zypper_search("-s -x -t package $libpackage");
    my %available_versions;
    $available_versions{$$_{version}} = 1 for (@$openssl_versions_rpm);

    if (scalar(keys %available_versions) == 0) {
        die "No $legacy_pkg_suffix packages found in repositories.";
    }

    # Inspect the 'Provides:' of the livepatch package.
    my $provides = script_output("zypper -n info --provides $packname");
    # Extract versions from Provides lines like:
    #   libssl_<version>_livepatchX.so()(...)
    #   libcrypto_<version>_livepatchX.so()(...)
    # Use a hash to deduplicate versions (libssl and libcrypto lines may both exist for the same version).
    my %lp_versions;
    $lp_versions{$_} = 1 for ($provides =~ m/^\s*lib(?:ssl|crypto)_([^()]+)_livepatch\d+\.so\(\)\([^)]+\)\s*$/gm);

    # Keep only versions that are available in repos
    my @targeted_versions = grep { defined($available_versions{$_}) } keys %lp_versions;

    if (scalar(@targeted_versions) == 0) {
        record_info('No Targets', "No livepatchable $legacy_pkg_suffix versions found based on $packname provides.");
        return undef;
    }

    record_info('Targets', "Found " . scalar(@targeted_versions) . " target openssl versions for testing.");
    # Generate temporary SSL certificates for the server.
    assert_script_run("openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes -subj '/CN=localhost' -passout pass:password");

    # Return RunArgs for the first iteration
    return OpenQA::Test::RunArgs->new(run_id => 0,
        target_versions => \@targeted_versions, packname => $packname);
}

sub get_livepatch_path {
    if (is_transactional()) {
        return "/var/livepatches/$legacy_pkg_suffix-livepatches/";
    } else {
        return "/usr/(lib64/)?$legacy_pkg_suffix-livepatches/";
    }
}

sub run {
    my ($self, $tinfo) = @_;
    select_serial_terminal;

    # Initial setup on first run
    if (!defined($tinfo)) {
        $tinfo = setup_openssl_test();
        # If no targets found, end the test normally.
        return if not defined($tinfo);
    }

    my $run_id = $tinfo->{run_id};
    my $target_ver = $tinfo->{target_versions}[$run_id];
    my $total_runs = scalar(@{$tinfo->{target_versions}});

    record_info('Test Iter', "Iteration " . ($run_id + 1) . "/$total_runs: Testing with $legacy_pkg_suffix-$target_ver");
    # Ensure livepatch is not installed from a previous run
    if (script_run("rpm -q $packname") == 0) {
        uninstall_package($packname);
    }
    record_info('Downgrade', "Installing old version: $legacy_pkg_suffix-$target_ver");
    # Force install the old package. Exit codes 106/107 indicate updates are available, which is expected.
    my $ssl_packs = zypper_search("-i $libpackage");
    my @downgrade_list = map { "$_->{name}=$target_ver" } @$ssl_packs;
    push @downgrade_list, "$legacy_pkg_suffix=$target_ver";
    install_package("--oldpackage " . join(' ', @downgrade_list), trup_continue => 1, trup_reboot => 1);

    # Start `openssl s_server` in the background. It's a long-running process that links with libssl/libcrypto.
    my $server_pid = background_script_run("$command s_server -cert cert.pem -key key.pem -pass pass:password -accept 44330 -www");
    record_info('Workload', "Started openssl s_server with PID $server_pid");

    # Verify the server is running and unpatched by checking its memory maps.
    # It should point to the standard /usr/lib64 locations.
    my $maps_before = script_output("cat /proc/$server_pid/maps | grep 'libcrypto\\|libssl'");
    my $expected_path = get_livepatch_path();
    if ($maps_before =~ m!$expected_path!) {
        die "Process is already patched before livepatch installation! Maps:\n$maps_before";
    }

    record_info('Install LP', "Installing livepatch package: $packname");
    # Refer ticket: poo#197309
    if (is_sle('=15-sp6')) {
        my $install_done = "Done executing rpm-helper";
        script_run("(zypper -n in -l $packname; echo $install_done) |& tee /dev/$serialdev", 0);
        wait_serial(qr/^$install_done/m, 800) || die "installation is not finished";
    } else {
        install_package($packname, timeout => 800);
    }

    # Get the list of livepatch files (.so) installed by the package.
    my $patch_files = script_output("rpm -ql $packname | grep '\\.so\$'");

    record_info('Trigger', "Triggering livepatches...");
    # Check the process's memory maps again. The libraries should now be mapped
    # from the livepatch directory (e.g., /usr/lib64/livepatch/...).
    my $maps_after = script_output("cat /proc/$server_pid/maps | grep 'libcrypto\\|libssl'");
    if ($maps_after !~ m!$expected_path!) {
        die "Livepatch was not applied to the process! It is still using original libs.\nMaps:\n$maps_after";
    }
    record_info('Verified', "Success! Process maps now point to livepatch files.");

    # Basic functionality check: verify the server still responds to a client.
    assert_script_run("openssl s_client -connect localhost:44330 -brief < /dev/null");

    # Kill the server process.
    script_run("kill -INT $server_pid");

    # If there are more versions to test, schedule this test module again.
    if ($run_id < $#{$tinfo->{target_versions}}) {
        my $next_runargs = OpenQA::Test::RunArgs->new(
            run_id => $run_id + 1,
            target_versions => $tinfo->{target_versions},
            packname => $packname
        );
        loadtest_kernel('ulp_openssl', run_args => $next_runargs);
    } else {
        record_info('Finished', "All target versions tested successfully.");
    }
}

sub test_flags {
    return {
        milestone => 1,
    };
}

sub post_fail_hook {
    my ($self) = @_;
    # Collect some debug info on failure
    script_run("ulp status");
    script_run("rpm -qi $packname");
    script_run("rpm -qi $legacy_pkg_suffix");
    # Remove temporary certificate files.
    assert_script_run("rm key.pem cert.pem");
    $self->SUPER::post_fail_hook;
}

1;
