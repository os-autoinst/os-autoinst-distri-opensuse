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
use publiccloud::utils;
use main_common qw(loadtest);
use testapi qw(check_var get_var);
use Utils::Architectures qw(is_aarch64 is_s390x);
use main_containers qw(load_container_tests);
require bmwqemu;

our @EXPORT = qw(load_publiccloud_tests load_publiccloud_download_repos);

sub load_maintenance_publiccloud_tests {
    my $args = OpenQA::Test::RunArgs->new();

    loadtest "publiccloud/download_repos" unless (check_var('PUBLIC_CLOUD_SKIP_MU', 1));
    loadtest "publiccloud/prepare_instance", run_args => $args;
    if (get_var('PUBLIC_CLOUD_REGISTRATION_TESTS')) {
        loadtest("publiccloud/check_registercloudguest", run_args => $args);
    } else {
        loadtest("publiccloud/registration", run_args => $args);
    }
    loadtest "publiccloud/transfer_repos", run_args => $args unless (check_var('PUBLIC_CLOUD_SKIP_MU', 1));
    loadtest "publiccloud/patch_and_reboot", run_args => $args;
    if (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
        loadtest "publiccloud/check_services", run_args => $args;
        loadtest("publiccloud/img_proof", run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_LTP')) {
        loadtest('publiccloud/run_ltp', run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_FUNCTIONAL')) {
        loadtest('publiccloud/cloud_netconfig', run_args => $args);
        loadtest('publiccloud/suspending', run_args => $args) if (is_sle('15-SP6+'));
    } elsif (check_var('PUBLIC_CLOUD_AHB', 1)) {
        loadtest('publiccloud/ahb', run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE')) {
        loadtest("publiccloud/bsc_1205002", run_args => $args);
    } elsif (get_var('PUBLIC_CLOUD_REGISTRATION_TESTS')) {
        loadtest("publiccloud/check_registercloudguest", run_args => $args);
    } else {
        loadtest "publiccloud/ssh_interactive_start", run_args => $args;
        loadtest "publiccloud/instance_overview", run_args => $args;
        if (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
            load_publiccloud_consoletests($args);
        } elsif (get_var('PUBLIC_CLOUD_BTRFS')) {
            loadtest 'publiccloud/btrfs', run_args => $args;
            loadtest 'publiccloud/snapper', run_args => $args;
        } elsif (get_var('PUBLIC_CLOUD_CONTAINERS')) {
            load_container_tests();
        } elsif (get_var('PUBLIC_CLOUD_XFS')) {
            loadtest "publiccloud/xfsprepare", run_args => $args;
        } elsif (get_var('PUBLIC_CLOUD_SMOKETEST')) {
            loadtest "publiccloud/smoketest";
            # flavor_check is concentrated on checking things which make sense only for image which is registered
            # against internal Public Cloud infra, so whenever we using SUSEConnect whole module does not make much sense
            loadtest "publiccloud/flavor_check" if (is_ec2() && !check_var('PUBLIC_CLOUD_SCC_ENDPOINT', 'SUSEConnect'));
            loadtest "publiccloud/sev" if (get_var('PUBLIC_CLOUD_CONFIDENTIAL_VM'));
            loadtest "publiccloud/xen" if (get_var('PUBLIC_CLOUD_XEN'));
            loadtest "publiccloud/hardened" if is_hardened;
        } elsif (get_var('PUBLIC_CLOUD_AZURE_NFS_TEST')) {
            loadtest("publiccloud/azure_nfs", run_args => $args);
        } elsif (check_var('PUBLIC_CLOUD_NVIDIA', 1)) {
            die "ConfigError: Either the provider is not supported or SLE version is old!\n" unless (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE') && is_sle('15-SP4+'));
            loadtest "publiccloud/nvidia", run_args => $args;
        } elsif (get_var('PUBLIC_CLOUD_EXTRATESTS')) {
            loadtest "publiccloud/selinux" if (is_sle("16.0+"));
        }

        loadtest("publiccloud/ssh_interactive_end", run_args => $args) unless get_var('PUBLIC_CLOUD_XFS');
    }
}

sub load_publiccloud_consoletests {
    my ($run_args) = @_;
    # Please pass the $run_args to fatal test modules
    loadtest 'console/cleanup_qam_testrepos' if get_var('PUBLIC_CLOUD_QAM');
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
    loadtest 'console/libgcrypt' unless check_var('BETA', '1') && !get_var('PUBLIC_CLOUD_QAM');
}

my $should_use_runargs = sub {
    my @public_cloud_variables = qw(
      PUBLIC_CLOUD_BTRFS
      PUBLIC_CLOUD_CONSOLE_TESTS
      PUBLIC_CLOUD_CONTAINERS
      PUBLIC_CLOUD_SMOKETEST
      PUBLIC_CLOUD_EXTRATESTS
      PUBLIC_CLOUD_AZURE_NFS_TEST
      PUBLIC_CLOUD_NVIDIA
      PUBLIC_CLOUD_FUNCTIONAL
      PUBLIC_CLOUD_AHB
      PUBLIC_CLOUD_NEW_INSTANCE_TYPE);
    return grep { exists $bmwqemu::vars{$_} } @public_cloud_variables;
};

sub load_latest_publiccloud_tests {
    my $args = OpenQA::Test::RunArgs->new();
    if (get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS')) {
        loadtest "publiccloud/img_proof", run_args => $args;
    }
    elsif (get_var('PUBLIC_CLOUD_LTP')) {
        loadtest 'publiccloud/run_ltp', run_args => $args;
    }
    elsif (get_var('PUBLIC_CLOUD_ACCNET')) {
        loadtest 'publiccloud/az_accelerated_net', run_args => $args;
    }
    elsif (get_var('PUBLIC_CLOUD_REGISTRATION_TESTS')) {
        loadtest "publiccloud/check_registercloudguest", run_args => $args;
    }
    elsif (get_var('PUBLIC_CLOUD_AZURE_AITL')) {
        loadtest "publiccloud/azure_aitl", run_args => $args;
    }
    elsif (&$should_use_runargs()) {
        loadtest "publiccloud/prepare_instance", run_args => $args;
        loadtest("publiccloud/registration", run_args => $args);
        if (get_var('PUBLIC_CLOUD_FUNCTIONAL')) {
            loadtest('publiccloud/cloud_netconfig', run_args => $args);
            loadtest('publiccloud/suspending', run_args => $args) if (is_sle('15-SP6+'));
        } elsif (check_var('PUBLIC_CLOUD_AHB', 1)) {
            loadtest('publiccloud/ahb', run_args => $args);
        } elsif (get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE')) {
            loadtest("publiccloud/bsc_1205002", run_args => $args);
        } else {
            loadtest("publiccloud/check_services", run_args => $args) if (get_var('PUBLIC_CLOUD_SMOKETEST'));
            loadtest "publiccloud/ssh_interactive_start", run_args => $args;
            loadtest "publiccloud/instance_overview", run_args => $args;
            if (get_var('PUBLIC_CLOUD_CONSOLE_TESTS')) {
                load_publiccloud_consoletests($args);
            } elsif (get_var('PUBLIC_CLOUD_BTRFS')) {
                loadtest 'publiccloud/btrfs', run_args => $args;
                loadtest 'publiccloud/snapper', run_args => $args;
            }
            elsif (check_var('PUBLIC_CLOUD_NVIDIA', 1)) {
                die "ConfigError: The provider is not supported\n" unless (check_var('PUBLIC_CLOUD_PROVIDER', 'GCE') && is_sle('15-SP4+'));
                loadtest "publiccloud/nvidia", run_args => $args;
            }
            elsif (get_var('PUBLIC_CLOUD_CONTAINERS')) {
                load_container_tests();
            } elsif (get_var('PUBLIC_CLOUD_SMOKETEST')) {
                loadtest "publiccloud/smoketest", run_args => $args;
                # flavor_check is concentrated on checking things which make sense only for image which is registered
                # against internal Public Cloud infra, so whenever we using SUSEConnect whole module does not make much sense
                loadtest "publiccloud/flavor_check", run_args => $args if (is_ec2() && !check_var('PUBLIC_CLOUD_SCC_ENDPOINT', 'SUSEConnect'));
                loadtest "publiccloud/sev", run_args => $args if (get_var('PUBLIC_CLOUD_CONFIDENTIAL_VM'));
                loadtest "publiccloud/xen", run_args => $args if (get_var('PUBLIC_CLOUD_XEN'));
            } elsif (get_var('PUBLIC_CLOUD_XFS')) {
                loadtest "publiccloud/xfsprepare", run_args => $args;
            } elsif (get_var('PUBLIC_CLOUD_AZURE_NFS_TEST')) {
                loadtest("publiccloud/azure_nfs", run_args => $args);
            } elsif (get_var('PUBLIC_CLOUD_EXTRATESTS')) {
                loadtest "publiccloud/selinux" if (is_sle("16.0+"));
            }
            loadtest("publiccloud/ssh_interactive_end", run_args => $args) unless get_var('PUBLIC_CLOUD_XFS');
        }
    }
    elsif (get_var('PUBLIC_CLOUD_UPLOAD_IMG')) {
        loadtest "publiccloud/upload_image", run_args => $args;
    } else {
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
    loadtest 'installation/bootloader_zkvm' if (is_s390x);
    loadtest 'boot/boot_to_desktop';
    if (get_var('PUBLIC_CLOUD_AZURE_CLI_TEST')) {
        loadtest 'publiccloud/azure_more_cli';
    } else {
        loadtest 'publiccloud/azure_cli' if (is_azure());
        loadtest 'publiccloud/aws_cli' if (is_ec2());
    }
}

sub load_publiccloud_download_repos {
    loadtest 'publiccloud/download_repos';
    loadtest 'shutdown/shutdown';
}

sub load_publiccloud_appimg_tests {
    my $args = OpenQA::Test::RunArgs->new();
    my $publiccloud_app_img = get_var('PUBLIC_CLOUD_APP_IMG');
    loadtest "publiccloud/prepare_instance", run_args => $args;
    loadtest("publiccloud/registration", run_args => $args);
    loadtest "publiccloud/instance_overview", run_args => $args;

    # This can be improved in the future with a hash like:
    # app_name => 'publiccloud/app-images/test-to-load'
    if ($publiccloud_app_img eq 'tomcat') {
        loadtest('publiccloud/app-images/tomcat', run_args => $args);
    } elsif ($publiccloud_app_img eq 'postgresql') {
        loadtest("publiccloud/ssh_interactive_start", run_args => $args);
        loadtest('console/postgresql_server', run_args => $args);
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
    }
    else {
        die("Unknown PUBLIC_CLOUD_APP_IMG setting");
    }
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
        if (get_var('PUBLIC_CLOUD_MIGRATION')) {
            my $args = OpenQA::Test::RunArgs->new();
            loadtest('publiccloud/upload_image', run_args => $args);
            loadtest('publiccloud/migration', run_args => $args);
        } elsif (check_var('PUBLIC_CLOUD_DOWNLOAD_TESTREPO', 1)) {
            load_publiccloud_download_repos();
        } elsif (get_var('PUBLIC_CLOUD_QAM')) {
            load_maintenance_publiccloud_tests();
        } elsif (get_var('PUBLIC_CLOUD_HIMMELBLAU')) {
            loadtest('publiccloud/himmelblau');
        } elsif (get_var('PUBLIC_CLOUD_APP_IMG')) {
            load_publiccloud_appimg_tests();
        } else {
            load_latest_publiccloud_tests();
        }
    }
}

1;
