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

my $wk_ker = 0;

sub prepare_azure {
    remove_kernel_packages();
    zypper_call("in -l kernel-azure", exitcode => [0, 100, 101, 102, 103], timeout => 700);
}

sub update_kernel {
    my ($repo, $patch, $incident_id) = @_;

    fully_patch_system;

    if ($incident_id) {
        my @repos = split(",", $repo);
        while (my ($i, $val) = each(@repos)) {
            zypper_call("ar $val kernel-update-$i");
        }
    }
    else {
        zypper_call("ar $repo kernel-update");
    }
    zypper_call("ref");

    #Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo) if $incident_id;

    if ((is_patch_needed($patch) && $patch) || ($incident_id && !($patches))) {
        die "Patch isn't needed";
    }
    else {
        # Use single patch or patch list
        $patch = $patch ? $patch : $patches;
        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1400);
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
        script_run("lsinitrd /boot/initrd-$kver-xen | awk '/-patch-.*ko\$/ || /livepatch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
        ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

        mod_rpm_info($module);
    }

    script_run("lsinitrd /boot/initrd-$kver-default | grep patch");
    save_screenshot;
    script_run("lsinitrd /boot/initrd-$kver-default | awk '/-patch-.*ko\$/ || /livepatch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
    ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

    mod_rpm_info($module);

    script_run("uname -a");
    save_screenshot;
}

sub install_lock_kernel {
    my $version = shift;
    if ($version eq '4.12.14-25.13.1') { $wk_ker = 1; }
    # version numbers can be 'out of sync'
    my $numbering_exception = {
        'kernel-source' => {
            '4.4.59-92.17.3'  => '4.4.59-92.17.2',
            '4.4.114-94.11.3' => '4.4.114-94.11.2',
            '4.4.126-94.22.1' => '4.4.126-94.22.2',
        },
        'kernel-macros' => {
            '4.4.59-92.17.3'  => '4.4.59-92.17.2',
            '4.4.114-94.11.3' => '4.4.114-94.11.2',
            '4.4.126-94.22.1' => '4.4.126-94.22.2',
        }};

    # remove all kernel related packages from system
    my @packages = remove_kernel_packages();

    my @lpackages = @packages;

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

    # install and lock needed kernel
    zypper_call("in " . join(' ', @packages), exitcode => [0, 102, 103, 104], timeout => 1400);
    zypper_call("al " . join(' ', @lpackages));
}

sub prepare_kgraft {
    my ($repo, $patch, $incident_id) = @_;
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
    if ($incident_id) {
        my @repos = split(",", $repo);
        while (my ($i, $val) = each(@repos)) {
            zypper_call("ar $val kgraft-test-repo-$i");

            my $kversion = script_output(q(zypper -n se -s kernel-default));
            my $pversion = script_output("zypper -n se -s -r kgraft-test-repo-$i");

            #disable kgraf-test-repo for while
            zypper_call("mr -d kgraft-test-repo-$i");

            my $wanted_version = right_kversion($kversion, $pversion);
            fully_patch_system;
            install_lock_kernel($wanted_version);
        }
    }
    else {
        zypper_call("ar $repo kgraft-test-repo");

        my $kversion = script_output(q(zypper -n se -s kernel-default));
        my $pversion = script_output(q(zypper -n se -r kgraft-test-repo -s));

        #disable kgraf-test-repo for while
        zypper_call("mr -d kgraft-test-repo");

        my $wanted_version = right_kversion($kversion, $pversion);
        fully_patch_system;
        install_lock_kernel($wanted_version);
    }
    type_string("reboot\n");
}

sub right_kversion {
    my ($kversion, $pversion) = @_;
    my ($kver_fragment) = $pversion =~ qr/(?:kgraft-|kernel-live)patch-(\d+_\d+_\d+-\d+_*\d*_*\d*)-default/;
    $kver_fragment =~ s/_/\\\./g;
    my ($real_version) = $kversion =~ qr/($kver_fragment\.*\d*)/;

    return $real_version;
}

sub update_kgraft {
    my ($repo, $patch, $incident_id) = @_;

    if ($incident_id) {
        my @repos = split(",", $repo);
        while (my ($i, $val) = each(@repos)) {
            zypper_call("mr -e kgraft-test-repo-$i");
        }
    }
    else {
        zypper_call("mr -e kgraft-test-repo");
    }
    zypper_call("ref");

    # Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo) if $incident_id;

    if (!($wk_ker) && ((is_patch_needed($patch) && $patch) || ($incident_id && !($patches)))) {
        die "Patch isn't needed";
    }
    else {
        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.before});
        upload_logs('/tmp/rpmlist.before');

        # Download HEAVY LOAD script
        assert_script_run("curl -f " . autoinst_url . "/data/qam/heavy_load.sh -o /tmp/heavy_load.sh");

        # install screen command
        zypper_call("in screen", exitcode => [0, 102, 103]);
        #run HEAVY Load script
        script_run("bash /tmp/heavy_load.sh");
        # warm up system
        sleep 15;

        # Use single patch or patch list
        $patch = $patch ? $patch : $patches;
        if ($wk_ker) {
            zypper_call("in -l  kernel-livepatch-4_12_14-25_13-default", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }
        else {
            zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        }

        #kill HEAVY-LOAD scripts
        script_run("screen -S LTP_syscalls -X quit");
        script_run("screen -S newburn_KCOMPILE -X quit");
        script_run("rm -Rf /var/log/qa");

        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.after});
        upload_logs('/tmp/rpmlist.after');
    }
}

sub run {
    my $self = shift;
    $self->wait_boot;

    select_console('root-console');

    my $repo = get_required_var('INCIDENT_REPO');

    # Set and check patch variables
    my $incident_id = get_var('INCIDENT_ID');
    my $patch       = get_var('INCIDENT_PATCH');
    check_patch_variables($patch, $incident_id);

    if (get_var('KGRAFT')) {
        my $qa_head = get_required_var('QA_HEAD_REPO');
        prepare_kgraft($repo, $patch, $incident_id);
        $self->wait_boot;
        select_console('root-console');

        # dependencies for heavy load script
        zypper_call("ar $qa_head qa_repo");
        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in qa_lib_ctcs2 qa_test_ltp qa_test_newburn");

        # update kgraft patch under heavy load
        update_kgraft($repo, $patch, $incident_id);

        zypper_call("rr qa_repo");
        zypper_call("rm qa_lib_ctcs2 qa_test_ltp qa_test_newburn");

        type_string("reboot\n");

        $self->wait_boot;
        select_console('root-console');

        kgraft_state;
    }
    elsif (get_var('AZURE')) {
        prepare_azure;
        update_kernel($repo, $patch, $incident_id);
    }
    else {
        update_kernel($repo, $patch, $incident_id);
    }

    type_string("reboot\n");
}

sub test_flags {
    return {fatal => 1};
}
1;
