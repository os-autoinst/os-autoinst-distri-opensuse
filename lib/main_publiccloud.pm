# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader of container tests
# Maintainer: qa-c@suse.de

package main_publiccloud;
use Mojo::Base 'Exporter';
use utils;
use version_utils;
use main_common qw(loadtest load_extra_tests_prepare);
use testapi qw(check_var get_var);
use Utils::Architectures qw(is_aarch64);

our @EXPORT = qw(
  load_publiccloud_tests
);

sub load_podman_tests() {
    loadtest 'containers/podman';
    loadtest 'containers/podman_3rd_party_images';
}

sub load_docker_tests() {
    loadtest 'containers/docker';
    loadtest 'containers/docker_runc' unless (is_aarch64 && is_sle('<=15'));
    loadtest 'containers/docker_3rd_party_images';
    loadtest 'containers/registry' unless (is_aarch64 && is_sle('<=15-SP1'));
    loadtest 'containers/zypper_docker' unless (is_aarch64 && is_sle('<=15'));
}

sub load_maintenance_publiccloud_tests {
    my $args = OpenQA::Test::RunArgs->new();

    loadtest "publiccloud/download_repos";
    loadtest "publiccloud/prepare_instance", run_args => $args;
    loadtest "publiccloud/register_system", run_args => $args;
    loadtest "publiccloud/transfer_repos", run_args => $args;
    loadtest "publiccloud/patch_and_reboot", run_args => $args;
    if (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
        loadtest("publiccloud/img_proof", run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_LTP')) {
        loadtest('publiccloud/run_ltp', run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_FIO')) {
        loadtest('publiccloud/storage_perf', run_args => $args);
    } else {
        loadtest "publiccloud/ssh_interactive_start", run_args => $args;
        loadtest "publiccloud/instance_overview" unless get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS');
        if (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
            load_extra_tests_prepare();
            load_publiccloud_consoletests();
        }
        if (get_var('PUBLIC_CLOUD_CONTAINERS')) {
            load_podman_tests() if is_sle('>=15-sp1');
            load_docker_tests();
        }
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
    }
}

sub load_publiccloud_consoletests {
    loadtest 'console/cleanup_qam_testrepos';
    loadtest 'console/openvswitch';
    loadtest 'console/rpm';
    loadtest 'console/openssl_alpn';
    loadtest 'console/check_default_network_manager';
    loadtest 'console/sysctl';
    loadtest 'console/sysstat';
    loadtest 'console/gpg';
    loadtest 'console/sudo';
    loadtest 'console/supportutils';
    loadtest 'console/journalctl';
    loadtest 'console/procps';
    loadtest 'console/suse_module_tools';
    loadtest 'console/libgcrypt';
}

sub load_publiccloud_tests {
    loadtest 'boot/boot_to_desktop';
    if (check_var('PUBLIC_CLOUD_DOWNLOAD_TESTREPO', 1)) {
        loadtest 'publiccloud/download_repos';
        loadtest 'shutdown/shutdown';
    }
    elsif (get_var('PUBLIC_CLOUD_QAM')) {
        load_maintenance_publiccloud_tests();
    } else {
        if (get_var('PUBLIC_CLOUD_PREPARE_TOOLS')) {
            loadtest "publiccloud/prepare_tools";
        }
        elsif (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
            loadtest "publiccloud/img_proof";
        }
        elsif (get_var('PUBLIC_CLOUD_LTP')) {
            loadtest 'publiccloud/run_ltp';
        }
        elsif (get_var('PUBLIC_CLOUD_SLES4SAP')) {
            loadtest 'publiccloud/sles4sap';
        }
        elsif (get_var('PUBLIC_CLOUD_ACCNET')) {
            loadtest 'publiccloud/az_accelerated_net';
        }
        elsif (get_var('PUBLIC_CLOUD_CHECK_BOOT_TIME')) {
            loadtest "publiccloud/boottime";
        }
        elsif (get_var('PUBLIC_CLOUD_FIO')) {
            loadtest 'publiccloud/storage_perf';
        }
        elsif (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
            my $args = OpenQA::Test::RunArgs->new();
            loadtest "publiccloud/prepare_instance", run_args => $args;
            loadtest "publiccloud/register_system", run_args => $args;
            loadtest "publiccloud/ssh_interactive_start", run_args => $args;
            load_extra_tests_prepare();
            load_publiccloud_consoletests();
            loadtest("publiccloud/ssh_interactive_end", run_args => $args);
        }
        elsif (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
            loadtest "publiccloud/upload_image";
        }
    }
}

1;
