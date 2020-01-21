# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs maint update under test for kernel/kgraft to ltp work image
# Maintainer: Ondřej Súkup osukup@suse.cz

use 5.018;
use warnings;
use strict;
use base 'opensusebasetest';
use testapi;
use utils;
use version_utils 'is_sle';
use qam;
use kernel 'remove_kernel_packages';
use power_action_utils 'power_action';
use repo_tools 'add_qa_head_repo';
use Utils::Backends 'use_ssh_serial_console';


my $wk_ker = 0;

# kernel-azure is never released in pool, first release is in updates.
# Fix the chicken & egg problem manually.
sub first_azure_release {
    my $repo = shift;

    remove_kernel_packages();
    fully_patch_system;

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("ar $val kernel-update-$i");
    }

    zypper_call("ref");
    zypper_call("in -l kernel-azure", exitcode => [0, 100, 101, 102, 103], timeout => 700);
    zypper_call('in kernel-devel');
}

sub prepare_azure {
    remove_kernel_packages();
    zypper_call("in -l kernel-azure", exitcode => [0, 100, 101, 102, 103], timeout => 700);
}

sub update_kernel {
    my ($repo, $incident_id) = @_;

    fully_patch_system;
    zypper_call('in kernel-devel') if is_sle('12+');

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("ar $val kernel-update-$i");
    }
    zypper_call("ref");

    #Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo);

    if ($incident_id && !($patches)) {
        die "Patch isn't needed";
    }
    else {
        # Use single patch or patch list
        zypper_call("in -l -t patch $patches", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1400);
    }
}

sub mod_rpm_info {
    my $module = shift;
    script_output("rpm -qf /$module");
    script_output("modinfo /$module");
}

sub kgraft_state {
    script_run("ls -lt /boot >/tmp/lsboot");
    upload_logs("/tmp/lsboot");
    script_run("cat /tmp/lsboot");
    save_screenshot;

    script_run("basename /boot/initrd-\$(uname -r) | sed s_initrd-__g > /dev/$serialdev", 0);
    my ($kver) = wait_serial(qr/(^[\d.-]+)-.+\s/) =~ /(^[\d.-]+)-.+\s/;
    my $module;

    # xen kernel exists only on SLE12 and SLE12SP1
    if (is_sle('<=12-SP1')) {
        script_run("lsinitrd /boot/initrd-$kver-xen | grep patch");
        save_screenshot;
        $module = script_output("lsinitrd /boot/initrd-$kver-xen | awk '/-patch-.*ko\$/ || /livepatch-.*ko\$/ {print \$NF}' > /dev/$serialdev");

        if (check_var('REMOVE_KGRAFT', '1')) {
            die 'Kgraft module exists when it should have been removed' if $module;
        }
        else {
            mod_rpm_info($module);
        }
    }

    script_run("lsinitrd /boot/initrd-$kver-default | grep patch");
    save_screenshot;
    $module = script_output("lsinitrd /boot/initrd-$kver-default | awk '/-patch-.*ko\$/ || /livepatch-.*ko\$/ {print \$NF}' > /dev/$serialdev");

    if (check_var('REMOVE_KGRAFT', '1')) {
        die 'Kgraft module exists when it should have been removed' if $module;
    }
    else {
        mod_rpm_info($module);
    }

    script_run("uname -a");
    save_screenshot;
}

sub install_lock_kernel {
    my $version = shift;
    if ($version eq '4.12.14-25.13.1')     { $wk_ker = 1; }
    if ($version eq '4.12.14-197.15.1')    { $wk_ker = 2; }
    if ($version eq '3.12.74-60.64.104.1') { $wk_ker = 3; }
    # version numbers can be 'out of sync'
    my $numbering_exception = {
        'kernel-source' => {
            '4.4.59-92.17.3'   => '4.4.59-92.17.2',
            '4.4.114-94.11.3'  => '4.4.114-94.11.2',
            '4.4.126-94.22.1'  => '4.4.126-94.22.2',
            '4.4.178-94.91.2'  => '4.4.178-94.91.1',
            '4.12.14-150.14.2' => '4.12.14-150.14.1',
        },
        'kernel-macros' => {
            '4.4.59-92.17.3'   => '4.4.59-92.17.2',
            '4.4.114-94.11.3'  => '4.4.114-94.11.2',
            '4.4.126-94.22.1'  => '4.4.126-94.22.2',
            '4.4.178-94.91.2'  => '4.4.178-94.91.1',
            '4.12.14-150.14.2' => '4.12.14-150.14.1',
        },
        'kernel-devel' => {
            '4.4.59-92.17.3'   => '4.4.59-92.17.2',
            '4.4.114-94.11.3'  => '4.4.114-94.11.2',
            '4.4.126-94.22.1'  => '4.4.126-94.22.2',
            '4.4.178-94.91.2'  => '4.4.178-94.91.1',
            '4.12.14-150.14.2' => '4.12.14-150.14.1',
        }};

    # remove all kernel related packages from system
    my @packages = remove_kernel_packages();

    my @lpackages = @packages;

    push @packages, "kernel-devel" if is_sle('12+');

    # extend list of packages with $version + workaround exceptions
    foreach my $package (@packages) {
        my $l_v = $version;
        for my $k (grep { $_ eq $package } keys %{$numbering_exception}) {
            for my $kk (keys %{$numbering_exception->{$k}}) {
                $l_v = $numbering_exception->{$k}->{$kk} if $version eq $kk;
            }
        }
        $package =~ s/$/-$l_v/;
    }

    # workaround for SLE15 - 4.12.4-25.13.1
    if ($wk_ker == 1) {
        @packages = grep { $_ ne 'kernel-source-4.12.14-25.13.1' } @packages;
    }

    # install and lock needed kernel
    zypper_call("in " . join(' ', @packages), exitcode => [0, 102, 103, 104], timeout => 1400);
    zypper_call("al " . join(' ', @lpackages));
}

sub prepare_kgraft {
    my ($repo, $incident_id) = @_;
    my $arch    = get_required_var('ARCH');
    my $version = get_required_var('VERSION');
    my $release_override;
    my $lp_product;
    my $lp_module;
    if ($version eq '12') {
        $release_override = '-d';
    }
    if (!is_sle('>=12-SP3')) {
        $version = '12';
    }
    # SLE15 has different structure of modules and products than SLE12
    if (is_sle('15+')) {
        $lp_product = 'sle-module-live-patching';
        $lp_module  = 'SLE-Module-Live-Patching';
    }
    else {
        $lp_product = 'sle-live-patching';
        $lp_module  = 'SLE-Live-Patching';
    }

    #install kgraft product
    zypper_call("ar http://download.suse.de/ibs/SUSE/Products/$lp_module/$version/$arch/product/ kgraft-pool");
    zypper_call("ar $release_override http://download.suse.de/ibs/SUSE/Updates/$lp_module/$version/$arch/update/ kgraft-update");
    zypper_call("ref");
    zypper_call("in -l -t product $lp_product", exitcode => [0, 102, 103]);
    zypper_call("mr -e kgraft-update");

    #add repository with tested patch
    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("ar $val kgraft-test-repo-$i");

        my $kversion = zypper_search(q(-s -x kernel-default));
        my $pversion = zypper_search("-s -t package -r kgraft-test-repo-$i");
        $pversion = join(' ', map { $$_{name} } @$pversion);

        #disable kgraf-test-repo for while
        zypper_call("mr -d kgraft-test-repo-$i");

        my $wanted_version = right_kversion($kversion, $pversion);
        fully_patch_system;
        install_lock_kernel($wanted_version);

        if (check_var('REMOVE_KGRAFT', '1')) {
            zypper_call("rm " . $pversion);
        }
    }

    power_action('reboot', textmode => 1);
}

sub right_kversion {
    my ($kversion, $pversion) = @_;
    my ($kver_fragment) = $pversion =~ qr/(?:kgraft-|kernel-live)patch-(\d+_\d+_\d+-\d+_*\d*_*\d*)-default/;
    $kver_fragment =~ s/_/\\\./g;

    for my $item (@$kversion) {
        return $$item{version} if $$item{version} =~ qr/^$kver_fragment\./;
    }

    die "Kernel $kver_fragment not found in repositories.";
}

sub update_kgraft {
    my ($repo, $incident_id) = @_;

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("mr -e kgraft-test-repo-$i");
    }

    # Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo);

    if (!($wk_ker) && ($incident_id && !($patches))) {
        die "Patch isn't needed";
    }
    else {
        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.before});
        upload_logs('/tmp/rpmlist.before');

        if (!$wk_ker) {
            # Download HEAVY LOAD script
            assert_script_run("curl -f " . autoinst_url . "/data/qam/heavy_load.sh -o /tmp/heavy_load.sh");

            # install screen command
            zypper_call("in screen", exitcode => [0, 102, 103]);
            #run HEAVY Load script
            script_run("bash /tmp/heavy_load.sh");

            # warm up system
            sleep 15;
        }
        # Use single patch or patch list
        if ($wk_ker == 1) {
            zypper_call("in -l  kernel-livepatch-4_12_14-25_13-default", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }
        elsif ($wk_ker == 2) {
            zypper_call("in -l  kernel-livepatch-4_12_14-197_15-default", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }
        elsif ($wk_ker == 3) {
            zypper_call("in -l kgraft-patch-3_12_74-60_64_104-xen kgraft-patch-3_12_74-60_64_104-default", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }
        else {
            zypper_call("in -l -t patch $patches", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }
        if (!$wk_ker) {
            #kill HEAVY-LOAD scripts
            script_run("screen -S LTP_syscalls -X quit");
            script_run("screen -S newburn_KCOMPILE -X quit");
            script_run("rm -Rf /var/log/qa");
        }
        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.after});
        upload_logs('/tmp/rpmlist.after');
    }
}

sub install_kotd {
    my $repo = shift;
    fully_patch_system;
    remove_kernel_packages;
    zypper_ar($repo, name => 'KOTD', priority => 90, no_gpg_check => 1);
    zypper_call("in -l kernel-default kernel-devel");
}

sub boot_to_console {
    my ($self) = @_;
    $self->wait_boot unless check_var('BACKEND', 'ipmi') && get_var('LTP_BAREMETAL');
    if (check_var('BACKEND', 'ipmi')) {
        use_ssh_serial_console;
    }
    else {
        select_console('root-console');
    }
}

sub run {
    my $self = shift;
    boot_to_console($self);

    my $repo        = get_var('KOTD_REPO');
    my $incident_id = undef;
    unless ($repo) {
        $repo        = get_required_var('INCIDENT_REPO');
        $incident_id = get_required_var('INCIDENT_ID');
    }

    if (get_var('KGRAFT')) {
        prepare_kgraft($repo, $incident_id);
        boot_to_console($self);

        if (!check_var('REMOVE_KGRAFT', '1')) {
            # dependencies for heavy load script
            if (!$wk_ker) {
                add_qa_head_repo;
                zypper_call("in qa_lib_ctcs2 qa_test_ltp qa_test_newburn");
            }

            # update kgraft patch under heavy load
            update_kgraft($repo, $incident_id);

            if (!$wk_ker) {
                zypper_call("rr qa-head");
                zypper_call("rm qa_lib_ctcs2 qa_test_ltp qa_test_newburn");
            }
            power_action('reboot', textmode => 1);

            boot_to_console($self);
        }

        kgraft_state;
    }
    elsif (get_var('AZURE')) {
        if (get_var('AZURE_FIRST_RELEASE')) {
            first_azure_release($repo);
        }
        else {
            prepare_azure;
            update_kernel($repo, $incident_id);
        }
    }
    elsif (get_var('KOTD_REPO')) {
        install_kotd($repo);
    }
    else {
        update_kernel($repo, $incident_id);
    }

    power_action('reboot', textmode => 1);
    $self->wait_boot if get_var('LTP_BAREMETAL');
}

sub test_flags {
    return {fatal => 1};
}
1;

=head1 Configuration

=head2 INCIDENT_REPO

Comma-separated repository URL list with packages to be tested. Used together
with KGRAFT, AZURE or in the default case. Mutually exclusive with KOTD_REPO.
INCIDENT_ID variable must be set to maintenance incident number.

=head2 KGRAFT

When KGRAFT variable evaluates to true, the incident is a kgraft/livepatch
test. Install one of the older released kernels and apply kgraft/livepatch
from incident repository to it.

=head2 AZURE

When AZURE variable evaluates to true, the incident is a public cloud kernel
test. Uninstall kernel-default and install kernel-azure instead. Then update
kernel as in the default case.

=head3 AZURE_FIRST_RELEASE

When AZURE_FIRST_RELEASE evaluates to true, install kernel-azure directly
from incident repository and update system. This is a chicken&egg workaround
because there is never any kernel-azure package in the pool repository.

=head2 KOTD_REPO

Repository URL for installing kernel of the day packages. Update system and
install new kernel using the simplified installation method.
