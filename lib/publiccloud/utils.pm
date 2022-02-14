# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Public cloud utilities
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

package publiccloud::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_public_cloud);
use publiccloud::ssh_interactive;
use registration;

our @EXPORT = qw(select_host_console is_byos is_ondemand is_ec2 is_azure is_gce registercloudguest register_addon);

# Select console on the test host, if force is set, the interactive session will
# be destroyed. If called in TUNNELED environment, this function die.
#
# select_host_console(force => 1)
#
sub select_host_console {
    my (%args) = @_;
    $args{force} //= 0;
    my $tunneled = get_var('TUNNELED');

    if ($tunneled && check_var('_SSH_TUNNELS_INITIALIZED', 1)) {
        die("Called select_host_console but we are in TUNNELED mode") unless ($args{force});

        opensusebasetest::select_serial_terminal();
        ssh_interactive_leave();

        select_console('tunnel-console', await_console => 0);
        send_key 'ctrl-c';
        send_key 'ret';

        set_var('_SSH_TUNNELS_INITIALIZED', 0);
        opensusebasetest::clear_and_verify_console();
        save_screenshot;
    }
    set_var('TUNNELED', 0) if $tunneled;
    opensusebasetest::select_serial_terminal();
    set_var('TUNNELED', $tunneled) if $tunneled;
}

sub register_addon {
    my ($remote, $addon) = @_;
    my $arch = get_var('PUBLIC_CLOUD_ARCH') // "x86_64";
    $arch = "aarch64" if ($arch eq "arm64");
    record_info($addon, "Going to register '$addon' addon");
    my $cmd_time = time();
    if ($addon =~ /ltss/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch, "-r " . get_required_var('SCC_REGCODE_LTSS'));
    } elsif (is_sle('<15') && $addon =~ /tcm|wsm|contm|asmm|pcm/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '`echo ${VERSION} | cut -d- -f1`', $arch);
    } elsif (is_sle('<15') && $addon =~ /sdk|we/) {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), '${VERSION_ID}', $arch);
    } else {
        ssh_add_suseconnect_product($remote, get_addon_fullname($addon), undef, $arch);
    }
    record_info('SUSEConnect time', 'The command SUSEConnect -r ' . get_addon_fullname($addon) . ' took ' . (time() - $cmd_time) . ' seconds.');
}

sub registercloudguest {
    my ($instance) = @_;
    my $regcode = get_required_var('SCC_REGCODE');
    my $remote = $instance->username . '@' . $instance->public_ip;
    # not all images currently have registercloudguest pre-installed .
    # in such a case,we need to regsiter against SCC and install registercloudguest with all needed dependencies and then
    # unregister and re-register with registercloudguest
    if ($instance->run_ssh_command(cmd => "sudo which registercloudguest > /dev/null; echo \"registercloudguest\$?\" ", proceed_on_failure => 1) =~ m/registercloudguest1/) {
        $instance->retry_ssh_command(cmd => "sudo SUSEConnect -r $regcode", timeout => 420, retry => 3);
        register_addon($remote, 'pcm');
        my $install_packages = 'cloud-regionsrv-client';    # contains registercloudguest binary
        if (is_azure()) {
            $install_packages .= ' cloud-regionsrv-client-plugin-azure regionServiceClientConfigAzure regionServiceCertsAzure';
        }
        elsif (is_ec2()) {
            $install_packages .= ' cloud-regionsrv-client-plugin-ec2 regionServiceClientConfigEC2 regionServiceCertsEC2';
        }
        elsif (is_gce()) {
            $install_packages .= ' cloud-regionsrv-client-plugin-gce regionServiceClientConfigGCE regionServiceCertsGCE';
        }
        else {
            die 'Unexpected provider ' . get_var('PUBLIC_CLOUD_PROVIDER');
        }
        $instance->run_ssh_command(cmd => "sudo zypper -q -n in $install_packages", timeout => 420);
        $instance->run_ssh_command(cmd => "sudo registercloudguest --clean");
    }
    # Check what version of registercloudguest binary we use
    $instance->run_ssh_command(cmd => "sudo rpm -qa cloud-regionsrv-client", proceed_on_failure => 1);
    # Register the system
    my $cmd_time = time();
    $instance->retry_ssh_command(cmd => "sudo registercloudguest -r $regcode", timeout => 420, retry => 3);
    record_info('registercloudguest time', 'The command registercloudguest took ' . (time() - $cmd_time) . ' seconds.');
}

# Check if we are a BYOS test run
sub is_byos() {
    return is_public_cloud && get_var('FLAVOR') =~ 'BYOS';
}

# Check if we are a OnDemand test run
sub is_ondemand() {
    # By convention OnDemand images are not marked explicitly.
    # Check all the other flavors, and if they don't match, it must be on_demand.
    return is_public_cloud && (!is_byos());    # When introducing new flavors, add checks here accordingly.
}

# Check if we are on an AWS test run
sub is_ec2() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
}

# Check if we are on an Azure test run
sub is_azure() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
}

# Check if we are on an GCP test run
sub is_gce() {
    return is_public_cloud && check_var('PUBLIC_CLOUD_PROVIDER', 'GCE');
}

1;
