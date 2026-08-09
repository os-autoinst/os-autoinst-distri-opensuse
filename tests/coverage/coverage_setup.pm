# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: setup coverage tooling
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use version_utils qw (is_sle has_selinux);
use serial_terminal 'select_serial_terminal';
use scheduler 'get_test_suite_data';
use repo_tools 'add_qa_head_repo';

sub run {
    select_serial_terminal;
    my $test_data = get_test_suite_data();
    my %repositories;

    if (is_sle '>=15-SP4') {
        add_qa_head_repo;
        assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
        my $version = get_required_var('VERSION');
        my $baseurl = 'http://download.suse.de/ibs/SUSE/Products';
        my $debug_suffix = 'x86_64/product_debug/';
        %repositories = (
            basesystem_debug => "$baseurl/SLE-Module-Basesystem/$version/$debug_suffix",
            serverapp_debug  => "$baseurl/SLE-Module-Server-Applications/$version/$debug_suffix",
            legacy_debug     => "$baseurl/SLE-Module-Legacy/$version/$debug_suffix",
            scripting_debug  => "$baseurl/SLE-Module-Web-Scripting/$version/$debug_suffix",
        );
    } else {
        assert_script_run 'setenforce 0' if has_selinux;
        %repositories = (
            devtools => 'http://download.opensuse.org/repositories/devel:/tools/openSUSE_Tumbleweed',
            main     => 'http://download.opensuse.org/tumbleweed/repo/oss/',
            # update repo skipped - causes zypper ref failures when snapshot changes
            debug    => 'http://download.opensuse.org/debug/tumbleweed/repo/oss/');
    }
    while (my ($name, $url) = each(%repositories)) {
        assert_script_run "zypper ar -e -f $url $name";
        # Append type=rpm-md to prevent zypper probing for media.1/media
        # (absent on HTTP repos; CDN returns 404 causing fatal zypper error)
        assert_script_run "echo type=rpm-md >> /etc/zypp/repos.d/$name.repo";
    }

    # Force refresh all repos to pick up latest metadata
    # (needed when TW publishes a new snapshot while we use an older ISO)
    # Retry zypper ref up to 3 times - SLIRP DNS may not be ready immediately
    for my $attempt (1..3) {
        last if script_run(q{zypper --gpg-auto-import-keys ref --force 2>&1 | tail -5}, timeout => 300) == 0;
        record_info("zypper ref retry", "Attempt $attempt failed, retrying in 30s");
        sleep 30;
    }

    my (@packages, @binaries);
    while (my ($pkg, $targets) = each(%{$test_data->{coverage_targets}})) {
        push @packages, $pkg, $pkg . '-debuginfo';
        my @pkg_bins = ref($targets) eq 'ARRAY' ? @$targets : ($targets);
        push @binaries, @pkg_bins;
    }
    for (@{$test_data->{helper_packages} // []}) {
        push @packages, $_;
    }
    push @packages, 'coverage-tools', 'elfutils';

    # Split packages into batches of 20 to avoid serial console input buffer overflow
    # on very large coverage target lists (100+ packages = 3000+ char command line)
    my @pkg_chunks;
    while (@packages) { push @pkg_chunks, [splice(@packages, 0, 20)] }
    for my $chunk (@pkg_chunks) {
        zypper_call q{--gpg-auto-import-keys in } . join(q{ }, @{$chunk});
    }

    my $log_dir = '/var/coverage/data';
    assert_script_run "mkdir -m 0777 -p $log_dir";

    assert_script_run 'funkoverage setup';

    # funkoverage install soft-fails per binary and exits non-zero if any fail.
    # Split binaries into batches of 15 to avoid serial console input buffer overflow.
    assert_script_run 'true > /tmp/fv_install.log';
    my @bin_chunks;
    while (@binaries) { push @bin_chunks, [splice(@binaries, 0, 15)] }
    for my $bchunk (@bin_chunks) {
        script_run(q{funkoverage install } . join(q{ }, @{$bchunk}) . q{ 2>&1 >> /tmp/fv_install.log}, timeout => 300);
    }
    assert_script_run 'cat /tmp/fv_install.log';
}

sub test_flags { return {fatal => 1, milestone => 1} }
1;
