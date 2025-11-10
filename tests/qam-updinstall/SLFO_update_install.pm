# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Maintenance SLFO incident install test
#
#    Test is booting preinstalled qcow2 image, which is updated regularly
#    It saves time, test is quick does not need to wait until image is created
#    First is system updated, then preinstall  will install packages present
#    in patch then patch from update is installed and rebooted to make sure
#    system can boot
#
#    1) Update system with released updates and do reboot if needed
#    2) [Preinstall] install packages mentioned in each patch at once
#    3) [Patch] install patch
#    4) [New packages] install new packages if present
#    5) Reboot after installation
#    6) Rollback to state before patch if multiple patches are tested
#
# Maintainer: QE Core <qe-core@suse.com>

use base "opensusebasetest";

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);
use List::Util qw(first pairmap uniq);
use qam;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures qw(is_s390x);

my @conflicting_packages = (
    'coreutils-single',
    'nv-prefer-signed-open-driver',
    'nvidia-open-signed-kmp',
    'nvidia-open-driver-G06-signed-kmp-default',
    'nvidia-open-driver-G06-signed-kmp-64kb',
    'nvidia-open-driver-G06-signed-cuda-kmp-default',
    'nvidia-open-driver-G06-signed-cuda-kmp-64kb',
    'nvidia-open-driver-G06-signed-cuda-default-devel',
);

# We may need to skip installing some packages based on test requirements
# see example at poo#191485
my @skipped_pkgs = qw(kernel-kvmsmall kernel-kvmsmall-devel);

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { print\$2 }'|uniq|tr '\n' ' '");
    return split(/\s+/, $patches);
}

sub reboot_and_login {
    prepare_system_shutdown;
    my $textmode = 1;
    if (systemctl('is-enabled display-manager', ignore_failure => 1) == 0 && !is_s390x) {
        $textmode = 0;
        power_action('reboot');
        set_var('DESKTOP', 'gnome', reload_needles => 1);
    }
    else {
        power_action('reboot');
    }
    opensusebasetest::wait_boot(opensusebasetest->new(), bootloader_time => 200, textmode => $textmode);
    select_serial_terminal;
}

sub run {
    my ($self) = @_;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos = get_required_var('INCIDENT_REPO');
    my $rollback_number;

    select_serial_terminal;

    # Patch the SUT to a released state and reboot if reboot is needed;
    reboot_and_login if fully_patch_system == 102;

    set_var('MAINT_TEST_REPO', $repos);
    my $repos_count = add_test_repositories;
    record_info('Repos', script_output('zypper lr -u'));

    record_info 'Snapshot created', 'Snapshot for rollback';
    $rollback_number = script_output('snapper create --description "Pre-patch" -p');

    my @patches = get_patch($incident_id, $repos);
    record_info "Patches", "@patches";
    die 'No patch found!' unless scalar(@patches);

    for my $patch (@patches) {
        my @update_conflicts;
        # Get info about the update patch.
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

        # Make a list of the conflicting binaries in this patch
        my @patch_conflicts = uniq pairmap {
            map { $_ =~ /(^\s+(?<with_ext>\S*)(\.(?!src)\S* <))|^\s+(?!srcpackage:)(?<no_ext>\S*)/; $+{with_ext} // $+{no_ext} } @patchinfo[$a .. $b] } @ranges;
        print "Conflicting packages: @patch_conflicts\n";

        for my $pkg (@patch_conflicts) {
            if (grep($pkg eq $_, @conflicting_packages)) {
                push(@update_conflicts, $pkg);
                # remove the conflicting package from list which is used for preinstall
                @patch_conflicts = grep { !/$pkg/ } @patch_conflicts;
            }
        }

        for my $pkg (@skipped_pkgs) {
            @patch_conflicts = grep { !/$pkg/ } @patch_conflicts;
        }

        disable_test_repositories($repos_count);

        # install conflicting packages one by one
        if (@update_conflicts) {
            record_info 'Conflicts', "@update_conflicts";
            for my $single_package (@update_conflicts) {
                record_info 'Conflict preinstall', "Install conflicting package $single_package before update repo is enabled";
                zypper_call("-v in -l --force-resolution --solver-focus Update $single_package", exitcode => [0, 102, 103], log => "prepare_${patch}_${single_package}.log", timeout => 1500);

                enable_test_repositories($repos_count);

                # Patch binaries already installed.
                record_info 'Conflict install', "Install patch $patch with conflicting $single_package";
                zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 1500);

                record_info 'Conflict rollback', "Rollback patch $patch with conflicting $single_package";
                assert_script_run("snapper rollback $rollback_number");
                reboot_and_login;
                disable_test_repositories($repos_count);
            }
        }

        # Install released binaries present in patch
        record_info 'Preinstall', 'Install affected packages before update repo is enabled';
        zypper_call("--ignore-unknown in -l --force-resolution --solver-focus Update @patch_conflicts", exitcode => [0, 102, 103, 104], log => "prepare_$patch.log", timeout => 1500);
        record_soft_failure "poo#1234 Preinstalled package is missing, check log prepare_${patch}." if (script_run("grep 'not found in package names' /tmp/prepare_${patch}.log") == 0);

        enable_test_repositories($repos_count);

        # Patch binaries installed in preinstall
        record_info 'Patch', "Install patch $patch";
        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => "zypper_$patch.log", timeout => 1500);

        # Install binaries newly added by the incident
        if (scalar @new_binaries) {
            record_info 'New packages', "New packages: @new_binaries";
            zypper_call("in -l @new_binaries", exitcode => [0, 102, 103], log => "new_$patch.log", timeout => 1500);
        }

        if (is_s390x) {
            # Make sure that openssh-server-config-disallow-rootlogin is not installed
            # we need ssh to reconnect to s390x system after reboot
            zypper_call("rm openssh-server-config-disallow-rootlogin", exitcode => [0, 104]);
        }

        record_info 'Reboot after patch', "system is bootable after patch $patch";
        reboot_and_login;

        # no need to rollback last patch
        unless ($patch eq $patches[-1]) {
            record_info 'Rollback', "Rollback system before $patch";
            assert_script_run("snapper rollback $rollback_number");
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

sub test_flags {
    return {fatal => 1};
}

1;
