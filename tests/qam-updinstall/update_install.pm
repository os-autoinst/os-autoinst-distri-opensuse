# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates
#    3) install packages mentioned in patch
#    5) try install update and store install_logs
#    6) try reboot
#    7) all done
#
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "opensusebasetest";

use strict;
use warnings;

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);

use qam;
use maintenance_smelt qw(get_packagebins_in_modules get_incident_packages);
use testapi;

sub install_packages {
    my $patch_info = shift;
    my $pattern    = qr/\s+(\S+)(?!\.(src|nosrc))\.\S*\s<\s.*/;

    # loop over packages in patchinfo and try installation
    foreach my $line (split(/\n/, $patch_info)) {
        if (my ($package) = $line =~ $pattern and $1 !~ /-patch-/) {
            # uninstall conflicting packages to allow problemless install
            my %conflict = (
                'reiserfs-kmp-default'   => 'kernel-default-base',
                'kernel-default'         => 'kernel-default-base',
                'kernel-default-extra'   => 'kernel-default-base',
                'kernel-default-base'    => 'kernel-default',
                'kernel-azure'           => 'kernel-azure-base',
                'kernel-azure-base'      => 'kernel-azure',
                'kernel-rt'              => 'kernel-rt-base',
                'kernel-rt-base'         => 'kernel-rt',
                'kernel-xen'             => 'kernel-xen-base',
                'kernel-xen-base'        => 'kernel-xen',
                'xen-tools'              => 'xen-tools-domU',
                'xen-tools-domU'         => 'xen-tools',
                'p11-kit-nss-trust'      => 'mozilla-nss-certs',
                'rmt-server-config'      => 'rmt-server-pubcloud',
                'cluster-md-kmp-default' => 'kernel-default-base',
                'dlm-kmp-default'        => 'kernel-default-base',
                'gfs2-kmp-default'       => 'kernel-default-base',
                'ocfs2-kmp-default'      => 'kernel-default-base'
            );
            zypper_call("rm $conflict{$package}", exitcode => [0, 104]) if $conflict{$package};
            # go to next package if it's not provided by repos
            record_info('Not present', "$package is added in patch") && next if (script_run("zypper -n se -t package -x $package") == 104);
            # install package
            zypper_call("in -l $package", timeout => 1500, exitcode => [0, 102, 103]);
            save_screenshot;
        }
    }
}

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { printf \$2 }'", type_command => 1);
    $patches =~ s/\r//g;
    return $patches;
}

sub get_patchinfos {
    my ($patches) = @_;
    my $patches_status = script_output("zypper -n info -t patch $patches", 200);
    return $patches_status;
}

sub change_repos_state {
    my ($repos, $state) = @_;
    $repos =~ tr/,/ /;
    zypper_call("mr --$state $repos");
}

sub get_installed_bin_version {
    my $name = $_[0];
    if (not script_run("rpm -q $name")) {
        return script_output "rpm -q --queryformat '%{VERSION}-%{RELEASE}' $name";
    } else {
        return 0;
    }
}

sub get_results {
    my ($self) = @_;
    my ($bins_ref, $package_ref) = ($self->{bins}, $self->{package_list});
    my $output .= sprintf "%-30s %-30s %-30s %-30s\n", "Binary", "Previous", "Updated", "Status";
    foreach (sort(@$package_ref)) {
        my $result = $bins_ref->{$_}{update_status} ? 'Success' : 'Failure ';
        $output .= sprintf "%-30s %-30s %-30s %-30s\n", $_, $bins_ref->{$_}{old}, $bins_ref->{$_}{new}, $result;
    }
    return $output;
}

sub run {
    my ($self)      = @_;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos       = get_required_var('INCIDENT_REPO');

    select_console 'root-console';

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);

    fully_patch_system;

    set_var('MAINT_TEST_REPO', $repos);
    add_test_repositories;

    my $patches = get_patch($incident_id, $repos);

    my $patch_infos = get_patchinfos($patches);

    change_repos_state($repos, 'disable');

    install_packages($patch_infos);

    # Get packages affected by the incident.
    my @packages = get_incident_packages($incident_id);

    # Extract module name from repo url.
    my @modules = split(/,/, $repos);
    s{http.*SUSE_Updates_(.*)/}{$1} for @modules;

    # Get binaries that are in each package across the modules that are in the repos.
    my %bins;
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_modules({package_name => $_, modules => \@modules}));
    }

    my @l2          = grep { ($bins{$_}->{supportstatus} eq 'l2') } keys %bins;
    my @l3          = grep { ($bins{$_}->{supportstatus} eq 'l3') } keys %bins;
    my @unsupported = grep { ($bins{$_}->{supportstatus} eq 'unsupported') } keys %bins;

    # Store the version of the installed binaries before the update.
    foreach (keys %bins) {
        $bins{$_}->{old} = get_installed_bin_version($_);
    }

    change_repos_state($repos, 'enable');
    zypper_call("in -l -t patch ${patches}", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1500);

    # After the update has been applied check the new version and based on that
    # determine if the update was succesful.
    foreach (keys %bins) {
        $bins{$_}->{new} = get_installed_bin_version($_);
    }
    my $l3_results = "L3 binaries must always be updated.\n";
    foreach (@l3) {
        if ($bins{$_}->{old} eq $bins{$_}->{new} or not $bins{$_}->{new}) {
            $bins{$_}->{update_status} = 0;
        } else {
            $bins{$_}->{update_status} = 1;
        }
    }
    $l3_results .= get_results({bins => \%bins, package_list => \@l3});
    record_info('L3', $l3_results) if scalar(@l3);

    my $l2_results = "L2 binaries need not always be updated but they must be installed.\n";
    $bins{$_}->{update_status} = !!$bins{$_}->{new} foreach (@l2);
    $l2_results .= get_results({bins => \%bins, package_list => \@l2});
    record_info('L2', $l2_results) if scalar(@l2);

    my $unsupported_results = "Unsupported binaries are ignored.\n";
    $bins{$_}->{update_status} = 1 foreach (@unsupported);
    $unsupported_results .= get_results({bins => \%bins, package_list => \@unsupported});
    record_info('UNSUPPORTED', $unsupported_results) if scalar(@unsupported);

    record_soft_failure 'poo#67357 Some L3 binaries were not updated.'   if scalar(grep { !$bins{$_}->{update_status} } @l3);
    record_soft_failure 'poo#67357 Some L2 binaries were not installed.' if scalar(grep { !$bins{$_}->{update_status} } @l2);

    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

1;
