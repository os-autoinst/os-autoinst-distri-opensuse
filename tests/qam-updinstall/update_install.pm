# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates
#    3) install packages mentioned in patch
#    5) try install update and store install_logs
#    6) try reboot
#    7) all done
#
# Maintainer: Ondřej Súkup <osukup@suse.cz>, Anton Pappas <apappas@suse.com>

use base "opensusebasetest";
use strict;
use warnings;

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);
use List::Util qw(first pairmap uniq notall);
use qam;
use maintenance_smelt qw(get_packagebins_in_modules get_incident_packages);
use testapi;
use version_utils qw(is_sle);

sub has_conflict {
    my $binary = shift;
    my %conflict = (
        'reiserfs-kmp-default' => 'kernel-default-base',
        'kernel-default' => 'kernel-default-base',
        'kernel-default-extra' => 'kernel-default-base',
        'kernel-azure' => 'kernel-azure-base',
        'kernel-rt' => 'kernel-rt-base',
        'kernel-xen' => 'kernel-xen-base',
        'xen-tools' => 'xen-tools-domU',
        'p11-kit-nss-trust' => 'mozilla-nss-certs',
        'rmt-server-config' => 'rmt-server-pubcloud',
        'cluster-md-kmp-default' => 'kernel-default-base',
        'dlm-kmp-default' => 'kernel-default-base',
        'gfs2-kmp-default' => 'kernel-default-base',
        'ocfs2-kmp-default' => 'kernel-default-base',
        dpdk => 'dpdk-thunderx',
        'dpdk-devel' => 'dpdk-thunderx-devel',
        'dpdk-kmp-default' => 'dpdk-thunderx-kmp-default',
        'pulseaudio-module-gconf' => 'pulseaudio-module-gsettings',
        'systemtap-sdt-devel' => 'systemtap-headers',
        libldb2 => 'libldb1',
        'python3-ldb' => 'python-ldb',
        'chrony-pool-suse' => 'chrony-pool-empty',
        libGLwM1 => 'libGLw1',
        libiterm1 => 'terminfo-iterm',
        rust => 'rls',
        'rust-gdb' => 'cargo',
        'openssl-1_0_0' => 'openssl-1_1',
        'libsamba-errors0' => 'samba-client-libs',
        rpm => 'rpm-ndb',
        'SAPHanaSR-ScaleOut' => 'SAPHanaSR',
        'SAPHanaSR-ScaleOut-doc' => 'SAPHanaSR-doc',
        'dapl-devel' => 'dapl-debug-devel',
        'libdat2-2' => 'dapl-debug-libs',
        dapl => 'dapl-debug'
    );
    return $conflict{$binary};
}

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { printf \$2 }'", type_command => 1);
    $patches =~ s/\r//g;
    return $patches;
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
    my ($self) = @_;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos = get_required_var('INCIDENT_REPO');

    $self->select_serial_terminal;

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);
    zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Updates/SLE-Live-Patching/12-SP3/" . get_var('ARCH') . "/update/ sle-module-live-patching:12-SP3::update") if is_sle('=12-SP3');

    # Get packages affected by the incident.
    my @packages = get_incident_packages($incident_id);

    # Extract module name from repo url.
    my @modules = split(/,/, $repos);
    foreach (@modules) {
        # substitue SLES_SAP for LTSS repo at this point is SAP ESPOS
        $_ =~ s/SAP_(\d+(-SP\d)?)/$1-LTSS/;
        next if s{http.*SUSE_Updates_(.*)/?}{$1};
        die 'Modules regex failed. Modules could not be extracted from repos variable.';
    }

    # Get binaries that are in each package across the modules that are in the repos.
    my %bins;
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_modules({package_name => $_, modules => \@modules}));
    }
    die "Parsing binaries from SMELT data failed" if not keys %bins;

    my @l2 = grep { ($bins{$_}->{supportstatus} eq 'l2') } keys %bins;
    my @l3 = grep { ($bins{$_}->{supportstatus} eq 'l3') } keys %bins;
    my @unsupported = grep { ($bins{$_}->{supportstatus} eq 'unsupported') } keys %bins;

    # Patch the SUT to a released state;
    fully_patch_system;

    # Sort binaries into:
    my %installable;    #Binaries already released that can already be installed.
    my @new_binaries;    #Binaries introduced by the update that will be installed after the repos are added.

    foreach my $b (@l2, @l3) {
        if (zypper_call("se -t package -x $b", exitcode => [0, 104]) eq '104') {
            push(@new_binaries, $b);
        } else {
            $installable{$b} = 1;
        }
    }

    for my $package (sort keys %installable) {
        # check if we already skipped it
        next unless defined $installable{$package};
        # Remove binaries conflicting with the ones that are being tested.
        my $conflict = has_conflict($package);
        next unless $conflict;
        if ($installable{$conflict}) {
            record_info "CONFLICT!", "$package conflicts with $conflict. Skipping $conflict.";
            delete $installable{$conflict};
        } else {
            record_info "CONFLICT!", "$package conflicts with $conflict. Removing $conflict.";
            zypper_call("rm $conflict", exitcode => [0, 104]);
            save_screenshot;
        }
    }

    # Install released version of installable binaries.
    if (scalar(keys %installable)) {
        zypper_call("in -l " . join(' ', keys %installable), exitcode => [0, 102, 103], log => 'prepare.log', timeout => 1500);
    }

    # Store the version of the installed binaries before the update.
    foreach (keys %bins) {
        $bins{$_}->{old} = get_installed_bin_version($_);
    }

    set_var('MAINT_TEST_REPO', $repos);
    add_test_repositories;

    my $patches = get_patch($incident_id, $repos);

    # Check if the patch was correctly configured.
    # Get info about the patches included in the update.
    my @patchinfo = split '\n', script_output("zypper -n info -t patch $patches", 200);
    # Find the lines where the Conflict sections begins.
    foreach (0 .. $#patchinfo) {
        print "$_: $patchinfo[$_]\n";
    }
    my @conflict_indexes = grep { $patchinfo[$_] =~ /^Conflicts\D*(\d+)/ } 0 .. $#patchinfo;
    print "conflict_indexes @conflict_indexes\n";
    # Find the ranges where there are conflict sections.
    my @ranges = map { $patchinfo[$_] =~ /Conflicts\D*(?<num>\d+)/; ($_ + 1, $_ + $+{num}) } @conflict_indexes;
    print "ranges @ranges\n";
    # Make a list of the conflicting binaries.
    my @conflict_names = uniq pairmap {
        map { $_ =~ /(^\s+(?<with_ext>\S*)(\.\S* <))|^\s+(?<no_ext>\S*)/; $+{with_ext} // $+{no_ext} } @patchinfo[$a .. $b] } @ranges;
    print "Conflict names: @conflict_names\n";
    # Get the l3 released binaries. Only installed binaries can conflict.
    my @installable_l3 = grep { $bins{$_}->{supportstatus} eq 'l3' } keys %installable;
    # If not all l3 released binaries are in the conflict binaries, fail.
    print "\nInstallable L3 @installable_l3\n";
    for my $package (@installable_l3) {
        my $hit = first { $package eq $_ } @conflict_names;
        unless ($hit) {
            record_info "Error", "$package is l3 but does not exist in the patch. The update may have been misconfigured";
        }
    }

    # Patch binaries already installed.
    zypper_call("in -l -t patch ${patches}", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1500);

    # Install binaries newly added by the incident.
    if (scalar @new_binaries) {
        zypper_call("in -l @new_binaries", exitcode => [0, 102, 103], log => 'new.log', timeout => 1500);
    }


    # After the patches have been applied and the new binaries have been
    # installed, check the version again and based on that determine if the
    # update was succesfull.
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

    record_soft_failure 'poo#67357 Some L3 binaries were not updated.' if scalar(grep { !$bins{$_}->{update_status} } @l3);
    record_soft_failure 'poo#67357 Some L2 binaries were not installed.' if scalar(grep { !$bins{$_}->{update_status} } @l2);

    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

1;
