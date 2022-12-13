# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates
#    3) install packages mentioned in each patch at once
#       update can contain multiple patches which could together conflict
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
use serial_terminal 'select_serial_terminal';
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
        # rpm-ndb can't be installed, it will remove rpm and break rpmdb2solv -> zypper
        'rpm-ndb' => 'rpm-ndb',
        'SAPHanaSR-ScaleOut' => 'SAPHanaSR',
        'SAPHanaSR-ScaleOut-doc' => 'SAPHanaSR-doc',
        'dapl-devel' => 'dapl-debug-devel',
        'libdat2-2' => 'dapl-debug-libs',
        'libjpeg8-devel' => 'libjpeg62-devel',
        dapl => 'dapl-debug'
    );
    $conflict{'kernel-default-kgraft'} = 'kernel-default-kgraft' if get_var('BUILD') =~ /kernel/ && check_var('VERSION', '12-SP3');
    return $conflict{$binary};
}

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { print\$2 }'|uniq|tr '\n' ' '");
    return $patches;
}

sub get_installed_bin_version {
    my $name = $_[0];
    # if there are multiple versions installed, store oldest installed version when looking for old, opposite for new
    my $age = $_[1];
    $age = $age eq 'old' ? 'head' : 'tail';
    if (not script_run("rpm -q $name")) {
        return script_output "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' $name|$age -n1", proceed_on_failure => 1;
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
    my %installable;    #Binaries already released that can already be installed.
    my @new_binaries;    #Binaries introduced by the update that will be installed after the repos are added.
    my %bins;

    select_serial_terminal;

    my $zypper_version = script_output(q(rpm -q zypper|awk -F. '{print$2}'));

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);
    zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Updates/SLE-Live-Patching/12-SP3/" . get_var('ARCH') . "/update/ sle-module-live-patching:12-SP3::update") if is_sle('=12-SP3');

    # Extract module name from repo url.
    my @modules = split(/,/, $repos);
    foreach (@modules) {
        # substitue SLES_SAP for LTSS repo at this point is SAP ESPOS
        $_ =~ s/SAP_(\d+(-SP\d)?)/$1-LTSS/;
        next if s{http.*SUSE_Updates_(.*)/?}{$1};
        die 'Modules regex failed. Modules could not be extracted from repos variable.';
    }

    # Patch the SUT to a released state;
    fully_patch_system;

    set_var('MAINT_TEST_REPO', $repos);
    my $repos_count = add_test_repositories;

    my $patches = get_patch($incident_id, $repos);

    # Get packages affected by the incident.
    my @packages = get_incident_packages($incident_id);

    # Get binaries that are in each package across the modules that are in the repos.
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_modules({package_name => $_, modules => \@modules}));
    }
    die "Parsing binaries from SMELT data failed" if not keys %bins;

    my @l2 = grep { ($bins{$_}->{supportstatus} eq 'l2') } keys %bins;
    my @l3 = grep { ($bins{$_}->{supportstatus} eq 'l3') } keys %bins;
    my @unsupported = grep { ($bins{$_}->{supportstatus} eq 'unsupported') } keys %bins;

    for my $patch (split(/\s+/, $patches)) {
        my %patch_bins = %bins;
        my (@patch_l2, @patch_l3, @patch_unsupported);

        # Check if the patch was correctly configured.
        # Get info about the patch included in the update.
        my @patchinfo = split '\n', script_output("zypper -n info -t patch $patch", 200);

        # Find the lines where the Conflict sections begins.
        foreach (0 .. $#patchinfo) {
            print "$_: $patchinfo[$_]\n";
        }
        my @conflict_indexes = grep { $patchinfo[$_] =~ /^Conflicts\D*(\d+)/ } 0 .. $#patchinfo;
        print "conflict_indexes @conflict_indexes\n";

        # Find the ranges where there are conflict sections.
        my @ranges = map { $patchinfo[$_] =~ /Conflicts\D*(?<num>\d+)/; ($_ + 1, $_ + $+{num}) } @conflict_indexes;
        print "ranges @ranges\n";

        # Make a list of the conflicting binaries in this patch.
        my @conflict_names = uniq pairmap {
            map { $_ =~ /(^\s+(?<with_ext>\S*)(\.(?!src)\S* <))|^\s+(?<no_ext>\S*)/; $+{with_ext} // $+{no_ext} } @patchinfo[$a .. $b] } @ranges;
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

        # separate binaries from this one patch based on patch info
        for my $b (@l2) { push(@patch_l2, $b) if grep($b eq $_, @conflict_names); }
        for my $b (@l3) { push(@patch_l3, $b) if grep($b eq $_, @conflict_names); }
        for my $b (@unsupported) { push(@patch_unsupported, $b) if grep($b eq $_, @conflict_names); }
        %patch_bins = map { $_ => ${bins}{$_} } (@patch_l2, @patch_l3);

        disable_test_repositories($repos_count);

        foreach my $b (@patch_l2, @patch_l3) {
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
                @patch_l3 = grep !/$conflict/, @patch_l3;
                @patch_l2 = grep !/$conflict/, @patch_l2;
            } else {
                record_info "CONFLICT!", "$package conflicts with $conflict. Removing $conflict.";
                zypper_call("rm $conflict", exitcode => [0, 104]);
            }
        }

        # Install released version of installable binaries.
        # Make sure on SLE 15+ zyppper 1.14+ with '--force-resolution --solver-focus Update' patched binaries are installed
        my $solver_focus = $zypper_version >= 14 ? '--force-resolution --solver-focus Update ' : '';
        if (scalar(keys %installable)) {
            record_info 'Preinstall', 'Install affected packages before update repo is enabled';
            zypper_call("in -l $solver_focus" . join(' ', keys %installable), exitcode => [0, 102, 103], log => "prepare_$patch.log", timeout => 1500);
        }

        # Store the version of the installed binaries before the update.
        foreach (keys %patch_bins) {
            $patch_bins{$_}->{old} = get_installed_bin_version($_, 'old');
        }

        enable_test_repositories($repos_count);

        # Patch binaries already installed.
        record_info 'Install patch', "Install patch $patch";
        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 1500);

        # Install binaries newly added by the incident.
        if (scalar @new_binaries) {
            record_info 'Install new packages', "New packages: @new_binaries";
            zypper_call("in -l @new_binaries", exitcode => [0, 102, 103], log => "new_$patch.log", timeout => 1500);
        }

        # After the patches have been applied and the new binaries have been
        # installed, check the version again and based on that determine if the
        # update was succesfull.
        foreach (keys %patch_bins) {
            $patch_bins{$_}->{new} = get_installed_bin_version($_, 'new');
        }
        my $l3_results = "L3 binaries must always be updated.\n";
        foreach (@l3) {
            if ($patch_bins{$_}->{old} eq $patch_bins{$_}->{new} or not $patch_bins{$_}->{new}) {
                $patch_bins{$_}->{update_status} = 0;
            } else {
                $patch_bins{$_}->{update_status} = 1;
            }
        }
        $l3_results = get_results({bins => \%patch_bins, package_list => \@patch_l3});
        record_info('L3', $l3_results) if scalar(@patch_l3);

        my $l2_results = "L2 binaries need not always be updated but they must be installed.\n";
        $patch_bins{$_}->{update_status} = !!$patch_bins{$_}->{new} foreach (@patch_l2);
        $l2_results = get_results({bins => \%patch_bins, package_list => \@patch_l2});
        record_info('L2', $l2_results) if scalar(@patch_l2);

        my $unsupported_results = "Unsupported binaries are ignored.\n";
        $patch_bins{$_}->{update_status} = 1 foreach (@patch_unsupported);
        $unsupported_results = get_results({bins => \%patch_bins, package_list => \@patch_unsupported});
        record_info('UNSUPPORTED', $unsupported_results) if scalar(@patch_unsupported);

        record_soft_failure 'poo#67357 Some L3 binaries were not updated.' if scalar(grep { !$patch_bins{$_}->{update_status} } @patch_l3);
        record_soft_failure 'poo#67357 Some L2 binaries were not installed.' if scalar(grep { !$patch_bins{$_}->{update_status} } @patch_l2);

        disable_test_repositories($repos_count);
        record_info 'Uninstall patch', "Uninstall patch $patch";
        # update repos are disabled, zypper dup will downgrade packages from patch
        zypper_call('dup -l', exitcode => [0, 8]);
        # remove patched packages with multiple versions installed e.g. kernel-source
        foreach (@patch_l3, @patch_l2) {
            zypper_call("rm $_-\$(zypper se -si $_|awk 'END{print\$7}')", exitcode => [0, 104]) if script_output("rpm -q $_|wc -l", proceed_on_failure => 1) >= 2;
        }
        enable_test_repositories($repos_count);
    }

    # merge logs from all patches into one which is testreport template expecting
    foreach (qw(prepare zypper new)) {
        next if script_run("ls /tmp|grep ${_}_", die_on_timeout => 0);
        assert_script_run("cat /tmp/$_* > /tmp/$_.log");
        upload_logs("/tmp/$_.log");
    }

    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot(bootloader_time => 200);
}

sub test_flags {
    return {fatal => 1};
}

1;
