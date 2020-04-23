# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM incident install test in openQA
#   1. Find supported binaries and install released versions.
#   2. Install updates from the test repository.
#   3. Verify installation.
#   4. Restart system.
# Maintainers: Ondřej Súkup <osukup@suse.cz>, Anton Pappas <apappas@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use utils;
use power_action_utils qw(prepare_system_shutdown power_action);
use qam;
use testapi;

sub resolve_conflicts {
    my $pack_ref = $_[0];
    my %conflict = (
        'p11-kit-nss-trust' => 'mozilla-nss-certs',
        'mozilla-nss-certs' => 'p11-kit-nss-trust',
        'rmt-server-config' => 'rmt-server-pubcloud'
    );
    foreach (@{$pack_ref}) {
        zypper_call("rm $conflict{$_}", exitcode => [0, 104]) if exists($conflict{$_});
    }
}

sub get_installed_bin_version {
    my $name = $_[0];
    if (not script_run("rpm -q $name")) {
        return script_output "rpm -q --queryformat '%{VERSION}-%{RELEASE}' $name";
    } else {
        return 0;
    }
}

sub get_patchnames {
    # Parse zypper patches output to find the name of the patches
    my ($self) = @_;
    my ($incident_id, $repos) = ($self->{incident_id}, $self->{repos});
    my $output = script_output("zypper patches -r @{$repos}", type_command => 1);
    my @patchnames;
    foreach my $line (split /\n/, $output) {
        print("line=$line\n");
        if ($line =~ m{\| +(.*$incident_id) +\|}) {
            push(@patchnames, $1);
        }
    }
    save_screenshot;
    return @patchnames;
}

sub report_results {
    my ($self) = @_;
    my ($bins, $l2_ref, $l3_ref) = ($self->{'bins'}, $self->{l2}, $self->{l3});
    my $output = sprintf "L3 (All must be installed and updated)\n";
    $output .= sprintf "%-30s %-30s %-30s\n", "Binary", "Previous", "Updated";
    foreach (sort(@{$l3_ref})) {
        my $result = ${$bins}{$_}->{'update_status'} ? 'Success' : 'Failure ';
        $output .= sprintf "%-30s %-30s %-30s %-30s\n", $_, ${$bins}{$_}->{'old'}, ${$bins}{$_}->{'new'}, $result;
    }
    record_info('L3', $output);
    if (scalar(@{$l2_ref})) {
        $output = sprintf "L2 (All must be installed but need not be updated)\n";
        my $result = ${$bins}{$_}->{'update_status'} ? 'Success' : 'Failure ';
        foreach (sort(@{$l2_ref})) {
            $output .= sprintf "%-30s %-30s %-30s %-30s\n", $_, ${$bins}{$_}->{'old'}, ${$bins}{$_}->{'new'}, $result;
        }
        record_info('L2', $output);
    }
}

sub run {
    #0. Initialize system.
    my ($self) = @_;
    select_console 'root-console';
    #Deactivate nVIDIA repos.
    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);
    fully_patch_system;
    #1. Find supported binaries and install released versions.
    #1.a) Query SMELT for the main package of the Maintenance Request.
    my $incident_id = get_required_var('INCIDENT_ID');
    my @repos       = split(/,/, get_required_var('INCIDENT_REPO'));
    my @packages    = get_packages_in_MR($incident_id);
    #1.b) Extract module names for supplied repos.
    my @modules;
    foreach (@repos) {
        if ($_ =~ m{SUSE_Updates_(?<product>.*)/}) {
            push(@modules, $+{product});
        }
    }
    #1.c) Query SMELT for name and maintenance status of binaries associated with the package.
    my %bins;
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_module({package => $_, module => \@modules}));
    }
    #1.d Seperate them according to maintenance status. Ignore unsupported.
    my @l2 = grep { ($bins{$_}->{'supportstatus'} eq 'l2') } keys %bins;
    my @l3 = grep { ($bins{$_}->{'supportstatus'} eq 'l3') } keys %bins;
    #1.e Find which binaries existed in the repos before the update.
    my @existing_bins = grep { not script_run("zypper -n se -t package -x $_") } (@l2, @l3);
    save_screenshot;
    #1.f) Remove conflicting binaries.
    resolve_conflicts(\@existing_bins);
    #1.g) Install packages that are in the repos.
    my $zypper_status = zypper_call("in -l @existing_bins", timeout => 1500, exitcode => [0, 102, 103], log => 'prepare.log');
    if ($zypper_status == 102) {
        prepare_system_shutdown;
        power_action("reboot");
        $self->wait_boot(bootloader_time => 200);
    }
    #1.h) Record binary versions before the update.
    foreach (@l2, @l3) {
        $bins{$_}->{'old'} = get_installed_bin_version($_);
    }

    #2. Install updates from the test repository.
    #2.a) Add test repositories.
    set_var('MAINT_TEST_REPO', get_required_var('INCIDENT_REPO'));
    add_test_repositories;
    #2.b) Query the test repos for available patches.
    my @patches = get_patchnames({incident_id => $incident_id, repos => \@repos});
    die "No patches to install" if !(scalar(@patches));
    #2.c) Install patches.
    zypper_call("in -l -t patch @patches", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1500);

    #3. Verify installation.
    #3.a) Record updated versions and compare them with the new updates.
    foreach (@l2, @l3) {
        $bins{$_}->{'new'} = get_installed_bin_version($_);
        if ($bins{$_}->{'old'} eq $bins{$_}->{'new'} or !$bins{$_}->{'new'}) {
            $bins{$_}->{'update_status'} = 0;
        } else {
            $bins{$_}->{'update_status'} = 1;
        }
    }
    report_results({l2 => \@l2, bins => \%bins, l3 => \@l3});
    die "Some L3 binaries were not updated."   if scalar(grep { !$bins{$_}->{'update_status'} } @l3);
    die "Some L2 binaries were not installed." if scalar(@l2) && scalar(grep { !$bins{$_}->{'new'} } @l2);

    #4. Restart system.
    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

1;
