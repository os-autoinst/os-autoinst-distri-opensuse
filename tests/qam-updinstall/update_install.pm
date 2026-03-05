# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates and do reboot if needed
#    3) install packages mentioned in each patch at once
#       update can contain multiple patches which could together conflict
#    4) conflicting packages will be installed one by one
#    5) install update, reboot end store install_logs
#    6) rollback to state before patch if multiple patches are tested
#    7) all done
#
#   variables: I added variables to contol behavior of the test when needed
#
#   UPDATE_ADD_CONFLICT
#     Add conflict manually, this was needed for expected openssh
#     collison on 12sp5, when when new bin had conflict with old ver
#     openssh is specific as it does no update but replace the old ver
#     see openssh.spec:
#     # To replace the openssh package:
#     Conflicts:      openssh < %{version}
#
#   UPDATE_PATCH_WITH_SOLVER_FEATURE
#     force-resolution feature is used only for preinstall and conflicts
#     this variable will enable it for patch when needed
#
#   Control solution option in sle12_zypp_resolve workaround function for SLE12
#   There is zypper version withou force-resolution feature, below are solution
#   option for each step sle12_zypp_resolve is used
#
#   UPDATE_RESOLVE_SOLUTION_CONFLICT_PREINSTALL
#   UPDATE_RESOLVE_SOLUTION_CONFLICT_INSTALL
#   UPDATE_RESOLVE_SOLUTION_CONFLICT_UNINSTALL
#   UPDATE_RESOLVE_SOLUTION_PREINSTALL
#   UPDATE_RESOLVE_SOLUTION_INSTALL
#   UPDATE_RESOLVE_SOLUTION_CONFLICT_INSTALL_NEW_BIN
#   UPDATE_RESOLVE_SOLUTION_UNINSTALL
#
#   UPDATE_NEW_BIN_ENABLE_REPLACEFILES
#     run install new bin/pacakage with --replacefiles, not enabled by default
#     would hide unintended conflict
#
#   UPDATE_PATCH_ENABLE_REPLACEFILES
#     run install patch with --replacefiles, not enabled by default
#     would hide unintended conflict
#
# Maintainer: Ondřej Súkup <osukup@suse.cz>, Anton Pappas <apappas@suse.com>

use base "opensusebasetest";

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);
use List::Util qw(first pairmap uniq);
use qam;
use maintenance_smelt qw(get_packagebins_in_modules get_incident_packages);
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle);
use Utils::Architectures qw(is_aarch64 is_ppc64le is_s390x);
use Data::Dumper qw(Dumper);

my @conflicting_packages = (
    'libwx_base-suse-nostl-devel', 'wxWidgets-3_2-nostl-devel',
    'cloud-netconfig-ec2', 'cloud-netconfig-gce', 'cloud-netconfig-azure',
    # can't be installed in parallel, Conflicts: otherproviders(waagent-config) see python-azure-agent.spec
    'python-azure-agent-config-server', 'python-azure-agent-config-micro',
    'python-azure-agent-config-hpc', 'python-azure-agent-config-default',
    'regionServiceClientConfigAzure', 'regionServiceClientConfigEC2', 'regionServiceClientConfigGCE',
    'libcontainers-openSUSE-policy',
    'mpich_4_0_2-gnu-hpc-macros-devel', 'mpich-ofi_4_0_2-gnu-hpc-macros-devel',
    'openmpi4-config', 'pmix-mca-params',
    'rmt-server-pubcloud',
    'systemtap-sdt-devel',
    'xen-tools-domU',
    'nfsidmap-devel',
    'libglfw3',
    'openvpn-dco',
    # docker-stable cannot be used alongside docker. see docker-stable.spec
    'docker-stable', 'docker-stable-bash-completion', 'docker-stable-zsh-completion', 'docker-zsh-completion',
    'libica-openssl1_1-tools', 'libica-devel', 'libica-devel-static',
    'cyrus-sasl-bdb-ntlm', 'cyrus-sasl-bdb-otp', 'cyrus-sasl-saslauthd-bdb', 'cyrus-sasl-otp',
    'cyrus-sasl-ntlm', 'cyrus-sasl-bdb-devel', 'cyrus-sasl-sqlauxprop',
    'nvidia-open-driver-G06-signed-cuda-default-devel', 'nvidia-open-driver-G06-signed-azure-devel',
    'nvidia-open-driver-G06-signed-cuda-64kb-devel',
    'kernel-firmware-nvidia-gspx-G06-cuda', 'nvidia-open-driver-G06-signed-cuda-kmp-default',
    'nv-prefer-signed-open-driver', 'nvidia-open-driver-G06-signed-cuda-kmp-azure',
    'nvidia-open-driver-G06-signed-cuda-kmp-64kb',
    'kernel-default-base', 'kernel-default-extra',
    'patterns-base-fips-certified',
    'gnu-compilers-hpc-macros-devel', 'gnu12-compilers-hpc-macros-devel',
    'openssl-ibmca-engine', 'openssl-ibmca-provider', 'openssl-ibmca',
    'openmpi3-config', 'openmpi2-config'
);

# https://progress.opensuse.org/issues/153388
push(@conflicting_packages, ('dpdk-thunderx', 'dpdk-thunderx-devel', 'dpdk-thunderx-kmp-default')) if is_aarch64;
push(@conflicting_packages, ('dpdk22-thunderx', 'dpdk22-thunderx-devel', 'dpdk22-thunderx-kmp-default')) if is_aarch64;

my @conflicting_packages_sle12 = ('apache2-prefork', 'apache2-doc', 'apache2-example-pages', 'apache2-utils', 'apache2-worker',
    'apache2-tls13', 'apache2-tls13-doc', 'apache2-tls13-example-pages', 'apache2-tls13-prefork', 'apache2-tls13-worker',
    'apache2-tls13-utils',
    # can't be installed in parallel, Conflicts: otherproviders(waagent-config) see python-azure-agent.spec
    'python-azure-agent-config-server', 'python-azure-agent-config-micro',
    'python-azure-agent-config-hpc', 'python-azure-agent-config-default'
);

# rpm-ndb can't be installed, it will remove rpm and break rpmdb2solv -> zypper
my @blocked_packages = ('rpm-ndb', 'kernel-default-base');

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { print\$2 }'|uniq|tr '\n' ' '");
    return split(/\s+/, $patches);
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

sub sle12_zypp_resolve {
    my ($cmd, $log, $solution) = @_;
    $solution //= 1;
    die '$cmd is required' unless defined $cmd;
    $log = " | tee /tmp/$log" if defined $log;
    script_output "expect -c '
        spawn $cmd;
        expect {
            \"Choose from\" {
                sleep 1
                send $solution\\r
                exp_continue
            }
            \"Continue\" {
                sleep 1
                send y\\r
                exp_continue
            }
            \"View the notifications now\" {
                sleep 1
                send n\\r
                exp_continue
            }
            -timeout -1 \"# \$\" {
                interact
            }
        }'$log
    ", 1500;
}

sub reboot_and_login {
    prepare_system_shutdown;
    power_action('reboot');
    opensusebasetest::wait_boot(opensusebasetest->new(), bootloader_time => 200);
    select_serial_terminal;
}

sub run {
    my ($self) = @_;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos = get_required_var('INCIDENT_REPO');
    my %installable;    #Binaries already released that can already be installed.
    my @new_binaries;    #Binaries introduced by the update that will be installed after the repos are added.
    my @new_binaries_conflicts;    #New binaries with conflict will be installed alone e.g. libwx_base-suse-nostl-devel conflicts with libwx_base-devel
    my (%bins, $rollback_number);

    if (get_var('BUILD') =~ /tomcat/ && get_var('HDD_1') =~ /SLED/) {
        record_info('not shipped', 'tomcat is not shipped to Desktop https://suse.slack.com/archives/C02D16TCP99/p1706675337430879');
        return;
    }

    select_serial_terminal;

    # remove phub repos on qemu update ppc64le https://progress.opensuse.org/issues/162704
    if (get_var('BUILD') =~ /qemu/ && get_var('INCIDENT_REPO') !~ /Packagehub-Subpackages/) {
        my $version = get_var('VERSION');
        record_info('remove phub', 'known conflict on qemu update with phub repo poo#162704');
        zypper_call("rr sle-module-packagehub-subpackages:${version}::pool sle-module-packagehub-subpackages:${version}::update");
    }

    my $zypper_version = script_output(q(rpm -q zypper|awk -F. '{print$2}'));

    zypper_call(q{mr -d $(zypper lr | awk -F '|' '/NVIDIA/ {print $2}')}, exitcode => [0, 3]);
    zypper_call(q{mr -f $(zypper lr | awk -F '|' '/SLES15-SP4-15.4-0/ {print $2}')}, exitcode => [0, 3]) if get_var('FLAVOR') =~ /TERADATA/;
    zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Updates/SLE-Live-Patching/12-SP3/" . get_var('ARCH') . "/update/ sle-module-live-patching:12-SP3::update") if is_sle('=12-SP3');

    # Extract module name from repo url.
    my @modules = split(/,/, $repos);
    foreach (@modules) {
        # substitue SLES_SAP for LTSS repo at this point is SAP ESPOS
        # workaround only availabe for 15-SP2
        $_ =~ s/SAP_(\d+(-SP\d)?)/$1-LTSS/ if is_sle('=15-SP2');

        next if s{http.*SUSE_Updates_(.*)/?}{$1};
        die 'Modules regex failed. Modules could not be extracted from repos variable.';
    }
    record_info('Modules', "@modules");

    # Patch the SUT to a released state and reboot if reboot is needed;
    reboot_and_login if fully_patch_system == 102;

    set_var('MAINT_TEST_REPO', $repos);
    my $repos_count = add_test_repositories;
    record_info('Repos', script_output('zypper lr -u'));

    record_info 'Snapshot created', 'Snapshot for rollback' if is_sle('12-sp3+');
    $rollback_number = script_output('snapper create --description "Pre-patch" -p') if is_sle('12-sp3+');

    my @patches = get_patch($incident_id, $repos);
    record_info "Patches", "@patches";
    die 'No patch found!' unless scalar(@patches);

    # Get packages affected by the incident.
    my @packages = get_incident_packages($incident_id);
    record_info('Packages', "@packages");

    # Get binaries that are in each package across the modules that are in the repos.
    foreach (@packages) {
        %bins = (%bins, get_packagebins_in_modules({package_name => $_, modules => \@modules}));
        # hash of hashes with keys 'name', 'supportstatus' and 'package'.
        # e.g. %SMELT_URL%/api/v1/basic/maintained/grub2
        record_info("$_", Dumper(\%bins));
    }
    die "Parsing binaries from SMELT data failed" if not keys %bins;

    my @l2 = grep { ($bins{$_}->{supportstatus} eq 'l2') } keys %bins;
    my @l3 = grep { ($bins{$_}->{supportstatus} eq 'l3') } keys %bins;
    my @unsupported = grep { ($bins{$_}->{supportstatus} eq 'unsupported') } keys %bins;

    for my $patch (@patches) {
        my %patch_bins = %bins;
        my (@patch_l2, @patch_l3, @patch_unsupported, @update_conflicts, $patch_info_status);
        my @conflicts = is_sle('<=12-SP5') ? @conflicting_packages_sle12 : @conflicting_packages;
        foreach (split(/,/, get_var('UPDATE_ADD_CONFLICT', ''))) {
            push(@conflicts, $_);
        }
        # Make sure on SLE 15+ zyppper 1.14+ with '--force-resolution --solver-focus Update' patched binaries are installed
        my $solver_focus = $zypper_version >= 14 ? '--force-resolution --solver-focus Update ' : '';

        # https://progress.opensuse.org/issues/131534
        next if $patch !~ /TERADATA/ && get_var('FLAVOR') =~ /TERADATA/;

        # Check if the patch was correctly configured.
        # Get info about the patch included in the update.
        my $patch_info = script_output("zypper -n info -t patch $patch", 200);
        my @patchinfo = split '\n', $patch_info;
        record_info "$patch", "$patch_info";

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
            map { $_ =~ /(^\s+(?<with_ext>\S*)(\.(?!src)\S* <))|^\s+(?!srcpackage:)(?<no_ext>\S*)/; $+{with_ext} // $+{no_ext} } @patchinfo[$a .. $b] } @ranges;
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
        for my $b (@l2) { push(@patch_l2, $b) if grep($b eq $_, @conflict_names) && grep($b ne $_, @blocked_packages); }
        for my $b (@l3) { push(@patch_l3, $b) if grep($b eq $_, @conflict_names) && grep($b ne $_, @blocked_packages); }
        for my $b (@unsupported) { push(@patch_unsupported, $b) if grep($b eq $_, @conflict_names); }
        %patch_bins = map { $_ => ${bins}{$_} } (@patch_l2, @patch_l3);

        disable_test_repositories($repos_count);

        foreach my $b (@patch_l2, @patch_l3) {
            if (zypper_call("se -t package -x $b", exitcode => [0, 104]) eq '104') {
                if (grep($b eq $_, @conflicts)) {
                    push(@new_binaries_conflicts, $b);
                }
                else {
                    push(@new_binaries, $b);
                }
            }
            else {
                $installable{$b} = 1 unless grep($b eq $_, @blocked_packages);
            }
        }

        for my $pkg (keys %installable) {
            if (grep($pkg eq $_, @conflicts)) {
                push(@update_conflicts, $pkg);
                delete($installable{$pkg});
            }
        }

        # handle conflicting packages one by one
        if (@update_conflicts) {
            record_info 'Conflicts', "@update_conflicts";
            for my $single_package (@update_conflicts) {
                record_info 'Conflict preinstall', "Install conflicting package $single_package before update repo is enabled";
                if ($solver_focus) {
                    zypper_call("-v in -l $solver_focus $single_package", exitcode => [0, 102, 103], log => "prepare_${patch}_${single_package}.log", timeout => 1500);
                }
                else {
                    sle12_zypp_resolve("zypper -v in -l $single_package", "prepare_${patch}_${single_package}.log", get_var('UPDATE_RESOLVE_SOLUTION_CONFLICT_PREINSTALL', 1));
                }

                enable_test_repositories($repos_count);

                $patch_info_status = script_output("zypper -n info -t patch $patch|grep Status");
                record_info "Patch status", "$patch_info_status";

                # Store version of installed binaries before update.
                $patch_bins{$single_package}->{old} = get_installed_bin_version($single_package, 'old') if $patch_info_status !~ /Status\s+: applied/;

                # Patch binaries already installed.
                record_info 'Conflict install', "Install patch $patch with conflicting $single_package";
                if ($solver_focus) {
                    zypper_call("in -l $solver_focus -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 2000);
                }
                else {
                    sle12_zypp_resolve("zypper -v in -l -t patch $patch", get_var('UPDATE_RESOLVE_SOLUTION_CONFLICT_INSTALL', 1));
                }

                # Store version of installed binaries after update.
                $patch_bins{$single_package}->{new} = get_installed_bin_version($single_package, 'new') if $patch_info_status !~ /Status\s+: applied/;

                record_info 'Conflict rollback', "Rollback patch $patch with conflicting $single_package";
                assert_script_run("snapper rollback $rollback_number") if is_sle('12-sp3+');
                reboot_and_login;
                disable_test_repositories($repos_count);
            }
        }

        # Install released version of installable binaries.
        if (scalar(keys %installable)) {
            record_info 'Preinstall', 'Install affected packages before update repo is enabled';
            if ($solver_focus) {
                zypper_call("--ignore-unknown in -l $solver_focus" . join(' ', keys %installable), exitcode => [0, 102, 103], log => "prepare_$patch.log", timeout => 1500);
                die "Package scriptlet failed, check log prepare_${patch}." if (script_run("grep 'scriptlet failed, exit status' /tmp/prepare_${patch}.log") == 0);
                record_soft_failure "poo#1234 Preinstalled package is missing, check log prepare_${patch}." if (script_run("grep 'not found in package names' /tmp/prepare_${patch}.log") == 0);
            }
            else {
                my $packages = join(' ', keys %installable);
                sle12_zypp_resolve("zypper -v in -l $packages", "prepare_$patch.log", get_var('UPDATE_RESOLVE_SOLUTION_PREINSTALL', 1));
            }
        }

        enable_test_repositories($repos_count);

        $patch_info_status = script_output("zypper -n info -t patch $patch|grep Status");
        record_info "Patch status", "$patch_info_status";

        if ($patch_info_status !~ /Status\s+: applied/) {
            # Store the version of the installed binaries before the update.
            for my $bin (keys %patch_bins) {
                next if grep($bin eq $_, @update_conflicts);
                $patch_bins{$bin}->{old} = get_installed_bin_version($bin, 'old');
            }
        }

        # Patch binaries already installed.
        my $patch_replacefiles = get_var('UPDATE_PATCH_ENABLE_REPLACEFILES') ? '--replacefiles' : '';
        record_info 'Install patch', "Install patch $patch";
        if (get_var('UPDATE_PATCH_WITH_SOLVER_FEATURE')) {
            if ($solver_focus) {
                zypper_call("in -l $patch_replacefiles $solver_focus -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 1500);
            }
            else {
                if (get_var('UPDATE_RESOLVE_SOLUTION_INSTALL')) {
                    sle12_zypp_resolve('zypper -v dup -l --replacefiles', "zypper_$patch.log", get_var('UPDATE_RESOLVE_SOLUTION_INSTALL', 1));
                }
                else {
                    zypper_call("in -l @new_binaries_conflicts", exitcode => [0, 102, 103], log => "new_${patch}_conflicts.log", timeout => 1500);
                }
            }
        }
        else {
            zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 1500);
        }

        # Install binaries newly added by the incident.
        if (scalar @new_binaries) {
            my $new_replacefiles = get_var('UPDATE_NEW_BIN_ENABLE_REPLACEFILES') ? '--replacefiles' : '';
            record_info 'Install new packages', "New packages: @new_binaries";
            zypper_call("in -l @new_binaries", exitcode => [0, 102, 103], log => "new_$patch.log", timeout => 1500);
        }

        foreach (@new_binaries_conflicts) {
            record_info 'New conflict', "Single conflicting package: $_";
            if (get_var('UPDATE_RESOLVE_SOLUTION_CONFLICT_INSTALL_NEW_BIN')) {
                sle12_zypp_resolve("zypper -v in -l $_", "new_${_}_conflicts.log", get_var('UPDATE_RESOLVE_SOLUTION_CONFLICT_INSTALL_NEW_BIN', 2));
            }
            else {
                zypper_call("in -l $solver_focus $_", exitcode => [0, 102, 103], log => "new_${_}_conflicts.log", timeout => 1500);
            }
        }

        if (is_s390x) {
            # Make sure that openssh-server-config-disallow-rootlogin is not installed
            # since in s390 we need to ssh to the system to reconnect to the tty after a reboot
            zypper_call("rm openssh-server-config-disallow-rootlogin", exitcode => [0, 104]);
        }

        record_info 'Reboot after patch', "system is bootable after patch $patch";
        reboot_and_login;

        if ($patch_info_status !~ /Status\s+: applied/ && script_run("grep '$patch already installed' /tmp/zypper_$patch.log") == 1) {
            # After and only if the patches have been applied and the new binaries
            # have been installed, check the version again and based on that
            # determine if the update was succesfull.
            for my $bin (keys %patch_bins) {
                next if grep($bin eq $_, @update_conflicts);
                $patch_bins{$bin}->{new} = get_installed_bin_version($bin, 'new');
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
        }

        # no need to rollback last patch
        unless ($patch eq $patches[-1]) {
            record_info 'Rollback', "Rollback system before $patch";
            assert_script_run("snapper rollback $rollback_number") if is_sle('12-sp3+');
            reboot_and_login;
        }
    }

    # merge logs from all patches into one which is testreport template expecting
    foreach (qw(prepare zypper new)) {
        next if script_run("timeout 20 ls /tmp|grep ${_}_");
        assert_script_run("cat /tmp/$_* > /tmp/$_.log");
        upload_logs("/tmp/$_.log");
    }
}

sub post_fail_hook {
    my $self = shift;
    force_soft_failure('Expected to fail') if get_var('BUILD') =~ /update-test-trivial/;
    return if get_var('BUILD') =~ /update-test-trivial/;
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;
