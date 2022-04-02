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
use main_common qw(loadtest);
use testapi qw(check_var get_var);
use Utils::Architectures qw(is_aarch64);
use main_containers qw(load_container_tests);

our @EXPORT = qw(
  load_publiccloud_tests
);

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
    } else {
        loadtest "publiccloud/ssh_interactive_start", run_args => $args;
        loadtest "publiccloud/instance_overview" unless get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS');
        if (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
            load_publiccloud_consoletests();
        } elsif (get_var('PUBLIC_CLOUD_CONTAINERS')) {
            load_container_tests();
        } elsif (get_var('PUBLIC_CLOUD_XFS')) {
            loadtest "publiccloud/xfsprepare";
            loadtest "xfstests/run";
            loadtest "xfstests/generate_report";
        }
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
    }
}

sub load_publiccloud_consoletests {
    loadtest 'console/cleanup_qam_testrepos' unless get_var('PUBLIC_CLOUD_QAM');
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

sub load_latest_publiccloud_tests {
    if (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
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
    elsif (get_var('PUBLIC_CLOUD_CONSOLE_TESTS') || get_var('PUBLIC_CLOUD_CONTAINERS')) {
        my $args = OpenQA::Test::RunArgs->new();
        loadtest "publiccloud/prepare_instance", run_args => $args;
        loadtest "publiccloud/register_system", run_args => $args;
        loadtest "publiccloud/ssh_interactive_start", run_args => $args;
        if (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
            load_publiccloud_consoletests();
        }
        elsif (get_var('PUBLIC_CLOUD_CONTAINERS')) {
            load_container_tests();
        } elsif (get_var('PUBLIC_CLOUD_XFS')) {
            loadtest "publiccloud/xfsprepare";
            loadtest "xfstests/run";
            loadtest "xfstests/generate_report";
        }
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
    }
    elsif (get_var('PUBLIC_CLOUD_UPLOAD_IMG')) {
        loadtest "publiccloud/upload_image";
    }
    else {
        die "*publiccloud - Latest* expects PUBLIC_CLOUD_* job variable. None is matched from the expected ones.";
    }
}

sub load_create_publiccloud_tools_image {
    loadtest 'autoyast/prepare_profile';
    loadtest 'installation/bootloader';
    loadtest 'autoyast/installation';
    loadtest 'publiccloud/prepare_tools';
    loadtest 'shutdown/shutdown';
}

# Test CLI tools for each provider
sub load_publiccloud_cli_tools {
    loadtest 'boot/boot_to_desktop';
    loadtest 'publiccloud/azure_cli';
    loadtest 'publiccloud/aws_cli';
    loadtest 'publiccloud/google_cli';
    loadtest 'shutdown/shutdown';
}

sub load_publiccloud_download_repos {
    loadtest 'publiccloud/download_repos';
    loadtest 'shutdown/shutdown';
}

=head2 load_publiccloud_tests

C<load_publiccloud_tests> schedules the test jobs for the variety of groups.
All the jobs expected to run after the B<publiccloud_download_testrepos> which boots from the preinstalled images
which B<create_hdd_autoyast_pc> publishes. The later is scheduled when I<PUBLIC_CLOUD_TOOLS_REPO> is defined and it is the only one which does not schedule C<boot/boot_to_desktop>. The C<boot/boot_to_desktop> is also run as an isolated smoke test in the B<PC Tools Image> job group.

The rest of the scheduling is divided into two separate subroutines C<load_maintenance_publiccloud_tests> and C<load_latest_publiccloud_tests>.

=cut

sub load_publiccloud_tests {
    if (check_var('PUBLIC_CLOUD_PREPARE_TOOLS', 1)) {
        load_create_publiccloud_tools_image();
    }
    elsif (check_var('PUBLIC_CLOUD_TOOLS_CLI', 1)) {
        load_publiccloud_cli_tools();
    }
    else {
        loadtest 'boot/boot_to_desktop';
        if (check_var('PUBLIC_CLOUD_DOWNLOAD_TESTREPO', 1)) {
            load_publiccloud_download_repos();
        }
        elsif (get_var('PUBLIC_CLOUD_QAM')) {
            load_maintenance_publiccloud_tests();
        } else {
            load_latest_publiccloud_tests();
        }
    }
}

1;
