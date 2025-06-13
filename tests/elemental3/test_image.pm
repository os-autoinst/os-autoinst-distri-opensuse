# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental ISO
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures qw(is_aarch64);

=head2 wait_kubectl_cmd

 wait_kubectl_cmd();

Wait for kubectl command to be available.

=cut

sub wait_kubectl_cmd {
    my $starttime = time;
    my $ret = undef;

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 480 : 240;

    while ($ret = script_run('which kubectl', ($timeout / 10))) {
        my $timerun = time - $starttime;
        if ($timerun < $timeout) {
            sleep 5;
        }
        else {
            die "kubectl command did not appear within $timeout seconds!";
        }
    }

    # Return the command status
    die 'Check did not return a defined value!' unless defined $ret;
    return $ret;
}

=head2 wait_k8s_running

 wait_k8s_running(regex);

Checks for up to B<$timeout> seconds whether K8s cluster is running.
Returns 0 if cluster is running or croaks on timeout.

=cut

sub wait_k8s_running {
    my ($regex) = shift;
    my $starttime = time;
    my $ret = undef;
    my $chk_cmd = 'kubectl get pod -A 2>&1';

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 480 : 240;

    while ($ret = script_run("! ($chk_cmd | grep -E -i -v -q '$regex')", ($timeout / 10))) {
        my $timerun = time - $starttime;
        if ($timerun < $timeout) {
            sleep 10;
        }
        else {
            record_info('RKE2 status', script_output("$chk_cmd"));
            die "K8s cluster did not start within $timeout seconds!";
        }
    }

    # Return the command status
    die 'Check did not return a defined value!' unless defined $ret;
    return $ret;
}

sub run {
    my ($self) = @_;
    my $rootpwd = get_required_var('TEST_PASSWORD');
    $testapi::password = $rootpwd;    # Set default root password

    # For HDD image boot
    if (check_var('IMAGE_TYPE', 'disk')) {
        # Wait for GRUB and select default entry
        $self->wait_grub(bootloader_time => 300);
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();
    }

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Record boot
    record_info('OS boot', 'Successfully booted!');

    # Wait for kubectl command to be available
    wait_kubectl_cmd();

    # Wait a bit for all processes to be launched
    sleep(60);

    # Check RKE2 status
    wait_k8s_running('status.*restarts|running|completed');

    # Record RKE2 status (we want all, stderr as well)
    record_info('RKE2 status', script_output('kubectl get pod -A 2>&1'));

    # Record RKE2 version/node
    record_info('RKE2 version/node', script_output('kubectl version; kubectl get nodes'));

    # Check toolkit version
    record_info('Toolkit version', script_output('elemental3-toolkit version'));
}

sub test_flags {
    return {fatal => 1};
}

1;
