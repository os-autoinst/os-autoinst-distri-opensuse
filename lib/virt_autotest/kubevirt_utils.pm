# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Utilities for setup kubevirt plugins and commands execution
# Maintainer: Nan Zhang <nan.zhang@suse.com> qe-virt@suse.de

package virt_autotest::kubevirt_utils;

use base Exporter;
use Exporter;

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_transactional);
use bootloader_setup qw(change_grub_config);

our @EXPORT = qw(
  set_grub_timeout
  install_cni_plugins
  select_kubevirt_packages
  replace_operator_images
  get_versioned_kubevirt_release
);

sub set_grub_timeout {
    my $grub_timeout = shift // 30;

    if (is_transactional) {
        change_grub_config('=.*', '=' . $grub_timeout, 'GRUB_TIMEOUT');
        record_info('GRUB', script_output('cat /etc/default/grub'));
        assert_script_run('transactional-update grub.cfg');
    }
}

sub get_versioned_kubevirt_release {
    # The versioned kubevirt RPM names (kubevirt-<release>-*) do not Provide the
    # legacy unversioned names; KUBEVIRT_VERSIONED_PKGS selects them and defaults
    # to on for SLE 15-SP7, with the release auto-detected from BUILD
    return undef unless (get_var('KUBEVIRT_VERSIONED_PKGS', get_var('VERSION') eq '15-SP7'));
    my ($release) = (get_var('BUILD') // '') =~ /kubevirt-(\d+\.\d+)/;
    return undef unless $release;
    # Streams before 1.6 ship the unversioned RPM names, so they keep the legacy
    # layout even on SLE 15-SP7 where the versioned packages default on;
    # kubevirt-1.6 (incident 47749) is the first stream with versioned names.
    my ($major, $minor) = split(/\./, $release);
    return undef if $major < 1 || ($major == 1 && $minor < 6);
    return $release;
}

sub _versioned_packages {
    my ($query, $base, $suffix, $repo) = @_;
    # Only <base><major>.<minor>-<suffix> matches. The dot is escaped because
    # it is a literal separator, not any character.
    my $pattern = '^ *' . $base . '[0-9]+\\.[0-9]+-' . $suffix . ' *$';
    # Restrict the search to $repo when the caller gives an alias.
    my $repo_option = defined $repo && $repo ne '' ? "-r $repo " : '';
    return split(/\n/, script_output("zypper se ${repo_option}$query | awk -F'|' '\$2 ~ /$pattern/ {gsub(/ /, \"\", \$2); print \$2}' | sort -Vu || true"));
}

sub select_kubevirt_packages {
    # Select the versioned kubevirt tests package and the CDI manifests package
    # that has the same rank. The repository decides the streams, so a product
    # with higher versions needs no code change (bsc#1252126).
    my ($repo_label, $tests_repo, $manifests_repo) = @_;

    my @kubevirt_tests = _versioned_packages('kubevirt', 'kubevirt', 'tests', $tests_repo);
    my $requested = get_var('KUBEVIRT_VERSION');
    my $virt_tests_pkg;
    if (defined $requested && $requested ne '') {
        $virt_tests_pkg = "kubevirt$requested-tests";
        die "Requested KubeVirt tests package $virt_tests_pkg is not in $repo_label ('zypper se kubevirt')"
          unless grep { $_ eq $virt_tests_pkg } @kubevirt_tests;
    } else {
        die "No versioned KubeVirt tests package (kubevirt<major>.<minor>-tests) is in $repo_label ('zypper se kubevirt')"
          unless @kubevirt_tests;
        # sort -V puts the highest version last, independent of string order.
        $virt_tests_pkg = $kubevirt_tests[-1];
    }

    my @kubevirt_streams = map { /^kubevirt([0-9.]+)-tests$/ ? $1 : () } @kubevirt_tests;
    my @cdi_manifests = _versioned_packages('containerized-data-importer', 'containerized-data-importer', 'manifests', $manifests_repo);
    my $kubevirt_list = join(', ', @kubevirt_tests);
    my $cdi_list = @cdi_manifests ? join(', ', @cdi_manifests) : 'none';
    die "No versioned CDI manifests package (containerized-data-importer<major>.<minor>-manifests) is in $repo_label ('zypper se containerized-data-importer')"
      unless @cdi_manifests;

    my ($kubevirt_stream) = $virt_tests_pkg =~ /^kubevirt([0-9.]+)-tests$/;
    my ($index) = grep { $kubevirt_streams[$_] eq $kubevirt_stream } 0 .. $#kubevirt_streams;
    die "KubeVirt stream $kubevirt_stream has no CDI counterpart in $repo_label; KubeVirt tests packages: $kubevirt_list; CDI manifests packages: $cdi_list"
      unless defined $index;

    # Pair by relative rank. A lone KubeVirt stream pairs with the newest CDI
    # stream even when older CDI streams remain in the repository.
    my $rank = @kubevirt_streams == 1 ? 1 : $index / $#kubevirt_streams;
    my $cdi_index = int($rank * $#cdi_manifests + 0.5);
    my $cdi_manifests_pkg = $cdi_manifests[$cdi_index];
    record_info('KubeVirt package selection', "KubeVirt tests: $virt_tests_pkg\nCDI manifests: $cdi_manifests_pkg\nRepository: $repo_label");
    return ($virt_tests_pkg, $cdi_manifests_pkg);
}

sub replace_operator_images {
    # Point only the intended operator components at the SUSE build of the
    # same version, leaving other operands in the manifest unchanged.
    my ($registry_host, $repo, $tag, $component_pattern, @manifest_paths) = @_;
    my ($version) = $tag =~ /^([^-]+)/;
    my $version_re = $version;
    $version_re =~ s/\./\\./g;
    foreach my $manifest (@manifest_paths) {
        assert_script_run(qq(sed -E -i "s#quay\\.io/kubevirt/($component_pattern):v?$version_re#$registry_host/$repo/\\1:$tag#g" $manifest));
    }
}

sub install_cni_plugins {
    # Setup cnv-bridge containernetworking plugin: one of the tests requires
    # a newer version of the Linux bridge CNI:
    #   https://github.com/kubevirt/kubevirt/commit/3fa7e2b67f9095d664e83eb1e13b587ab76b4950
    assert_script_run("curl -LO https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz");
    assert_script_run("curl -LO https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz.sha256");
    assert_script_run("sha256sum --check cni-plugins-linux-amd64-v1.1.1.tgz.sha256");
    assert_script_run("mkdir -p /opt/cni/bin");
    assert_script_run("tar -xOf cni-plugins-linux-amd64-v1.1.1.tgz ./bridge > /opt/cni/bin/cnv-bridge");
    assert_script_run("chmod +x /opt/cni/bin/cnv-bridge");
}

1;
