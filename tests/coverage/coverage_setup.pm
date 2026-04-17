# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: setup coverage tooling
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

# test_data in the YAML schedule must contain:
#   coverage_targets: hash of package_name -> binary (scalar) or [list of binaries]
#   helper_packages:  (optional) packages needed to make tests work, but NOT instrumented
#
# Example:
#   test_data:
#     helper_packages:
#       - wget
#     coverage_targets:
#       curl: /usr/bin/curl
#       net-snmp:
#         - /usr/bin/snmpget
#         - /usr/bin/snmpset
#
# BINARY_COVERAGE_GITREF: if set, build funkoverage from source on the SUT instead
# of installing the packaged coverage-tools RPM. Value must be a full git clone URL
# (any fork/branch works, e.g. a URL with a #branch suffix), not just a branch name.
# Upstream reference: https://github.com/ilmanzo/BinaryCoverage
# Example: BINARY_COVERAGE_GITREF=https://github.com/ilmanzo/BinaryCoverage#main

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use version_utils qw (is_sle has_selinux);
use serial_terminal 'select_serial_terminal';
use scheduler 'get_test_suite_data';
use repo_tools 'add_qa_head_repo';

sub run {
    select_serial_terminal;
    # enable debug repos
    # on Tumbleweed does not have debuginfo in to-be-tested snapshots, except for selected package

    # TODO maybe not the best way, but it works
    my $test_data = get_test_suite_data();
    my $gitref = get_var('BINARY_COVERAGE_GITREF');

    my %repositories;    # an hash of repositories to add

    if (is_sle '>=15-SP4') {
        add_qa_head_repo;
        # enable debug repos
        assert_script_run q(zypper mr -e $(zypper lr | awk '/Debug/ {print $1}'));
        my $version = get_required_var('VERSION');
        my $baseurl = 'http://download.suse.de/ibs/SUSE/Products';
        my $debug_suffix = 'x86_64/product_debug/';
        %repositories = (
            basesystem_debug => "$baseurl/SLE-Module-Basesystem/$version/$debug_suffix",
            serverapp_debug => "$baseurl/SLE-Module-Server-Applications/$version/$debug_suffix",
            legacy_debug => "$baseurl/SLE-Module-Legacy/$version/$debug_suffix",
            scripting_debug => "$baseurl/SLE-Module-Web-Scripting/$version/$debug_suffix",
        );
    } else {
        # set SELinux to permissive, as it is not supported by coverage tools
        assert_script_run 'setenforce 0' if has_selinux;
        %repositories = (
            devtools => 'http://download.opensuse.org/repositories/devel:/tools/openSUSE_Tumbleweed',
            main => 'http://download.opensuse.org/tumbleweed/repo/oss/',
            update => 'http://download.opensuse.org/update/tumbleweed/',
            debug => 'http://download.opensuse.org/debug/tumbleweed/repo/oss/');
    }
    while (my ($name, $url) = each(%repositories)) {
        # Priority 1: some HDD images already have a same-purpose debug repo (e.g. an
        # openQA asset-mirror one) baked in at a lower priority (higher number) that
        # only carries a curated package subset; ours must win so debuginfo actually
        # resolves against a repo that has it, not just one that was registered first.
        assert_script_run "zypper ar -e -f -p 1 $url $name";
    }

    # install coverage tools + debuginfo, and any helper packages
    my (@packages, @binaries);
    while (my ($pkg, $targets) = each(%{$test_data->{coverage_targets}})) {
        push @packages, $pkg, $pkg . '-debuginfo';
        my @pkg_bins = ref($targets) eq 'ARRAY' ? @$targets : ($targets);
        push @binaries, @pkg_bins;
    }
    for (@{$test_data->{helper_packages} // []}) {
        push @packages, $_;
    }
    push @packages, 'elfutils';
    push @packages, 'coverage-tools' unless $gitref;
    zypper_call '--gpg-auto-import-keys in ' . join ' ', @packages;

    # sets up the environment for coverage
    my $log_dir = '/var/coverage/data';

    assert_script_run "mkdir -m 0777 -p $log_dir";

    if ($gitref) {
        # build funkoverage from source instead of using the packaged coverage-tools.
        # $gitref is a full git URL (any fork), optionally with a '#branch' suffix.
        zypper_call 'in go git';
        my ($repo_url, $branch) = split /#/, $gitref, 2;
        assert_script_run 'git clone --depth 1 ' . ($branch ? "--branch $branch " : '')
          . "'$repo_url' /opt/BinaryCoverage", timeout => 300;
        assert_script_run 'cd /opt/BinaryCoverage && ./build.sh', timeout => 600;
        # build.sh's output path isn't pinned by contract; locate then install it.
        # funkoverage-shim must sit alongside funkoverage: install runs 'funkoverage
        # install' which shims target binaries and looks up the shim next to itself.
        assert_script_run 'install -m 0755 '
          . '"$(find /opt/BinaryCoverage -maxdepth 2 -type f -name funkoverage | head -1)" '
          . '/usr/local/bin/funkoverage';
        assert_script_run 'install -m 0755 '
          . '"$(find /opt/BinaryCoverage -maxdepth 2 -type f -name funkoverage-shim | head -1)" '
          . '/usr/local/bin/funkoverage-shim';
    }

    # set capabilities to run eBPF programs without root privileges
    assert_script_run 'funkoverage setup';

    # wrap the binaries that will be instrumented for 'coverage'
    assert_script_run "funkoverage install " . join ' ', @binaries;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
