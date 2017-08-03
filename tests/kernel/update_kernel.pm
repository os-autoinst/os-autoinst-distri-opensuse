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
use qam;

sub update_kernel {
    my ($repo, $patch) = @_;

    fully_patch_system;

    zypper_call("ar $repo kernel-update");
    zypper_call("ref");

    if (!is_patch_needed($patch)) {
        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => 'zypper.log');
    }
    else {
        die "Patch isn't needed";
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
    if (!sle_version_at_least('12-SP2')) {
        script_run("lsinitrd /boot/initrd-$kver-xen | grep patch");
        save_screenshot;
        script_run("lsinitrd /boot/initrd-$kver-xen | awk '/-patch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
        ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

        mod_rpm_info($module);
    }

    script_run("lsinitrd /boot/initrd-$kver-default | grep patch");
    save_screenshot;
    script_run("lsinitrd /boot/initrd-$kver-default | awk '/-patch-.*ko\$/ {print \$NF}' > /dev/$serialdev", 0);
    ($module) = wait_serial(qr/lib*/) =~ /(^.*ko)\s+/;

    mod_rpm_info($module);

    script_run("uname -a");
    save_screenshot;
}

sub install_lock_kernel {
    my $version = shift;
    # version numbers can be 'out of sync'
    my $numbering_exception = {
        'kernel-source' => {
            '4.4.59-92.17.3' => '4.4.59-92.17.2',
        },
        'kernel-macros' => {
            '4.4.59-92.17.3' => '4.4.59-92.17.2',
        }};

    my @packages = qw(kernel-default kernel-default-devel kernel-macros kernel-source);
    # SLE12 and SLE12SP1 has xen kernel
    if (!sle_version_at_least('12-SP2')) {
        push @packages, qw(kernel-xen kernel-xen-devel);
    }

    # remove all kernel related packages from system
    script_run("zypper -n rm " . join(' ', @packages), 700);

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
    zypper_call("in " . join(' ', @packages), exitcode => [0, 102, 103, 104]);
    zypper_call("al " . join(' ', @lpackages));
}

sub prepare_kgraft {
    my ($repo, $patch) = @_;
    my $arch    = get_required_var('ARCH');
    my $version = get_required_var('VERSION');
    my $release_override;
    if ($version eq '12') {
        $release_override = '-d';
    }
    if (!sle_version_at_least('12-SP3')) {
        $version = '12';
    }

    #install kgraft product
    zypper_call("ar http://download.suse.de/ibs/SUSE/Products/SLE-Live-Patching/$version/$arch/product/ kgraft-pool");
    zypper_call("ar $release_override http://download.suse.de/ibs/SUSE/Updates/SLE-Live-Patching/$version/$arch/update/ kgraft-update");
    zypper_call("ref");
    zypper_call("in sle-live-patching-release", exitcode => [0, 102, 103]);
    zypper_call("mr -e kgraft-update");

    #add repository with tested patch
    zypper_call("ar $repo kgraft-test-repo");
    my $kversion = script_output(q(zypper -n se -s kernel-default));
    my $pversion = script_output(q(zypper -n se -r kgraft-test-repo -s));

    #disable kgraf-test-repo for while
    zypper_call("mr -d kgraft-test-repo");

    my $wanted_version = right_kversion($kversion, $pversion);
    fully_patch_system;
    install_lock_kernel($wanted_version);
    # install released kGraft patches on top of wanted kernel
    zypper_call('patch --with-interactive -l', exitcode => [0, 102], timeout => 700);
    type_string("reboot\n");
}

sub right_kversion {
    my ($kversion, $pversion) = @_;

    my ($kver_fragment) = $pversion =~ qr/kgraft-patch-(\d+_\d+_\d+-\d+_*\d*_*\d*)-default/;
    $kver_fragment =~ s/_/\\\./g;
    my ($real_version) = $kversion =~ qr/($kver_fragment\.*\d*)/;

    return $real_version;
}

sub update_kgraft {
    my $patch = shift;
    zypper_call("mr -e kgraft-test-repo");
    zypper_call("ref");

    if (!is_patch_needed($patch)) {
        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.before});
        upload_logs('/tmp/rpmlist.before');

        # Download HEAVY LOAD script
        assert_script_run("curl -f " . autoinst_url . "/data/qam/heavy_load.sh -o /tmp/heavy_load.sh");

        #run HEAVY Load script
        script_run("bash /tmp/heavy_load.sh");
        # warm up system
        sleep 15;

        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => 'zypper.log');

        #kill HEAVY-LOAD scripts
        script_run("screen -S LTP_syscalls -X quit");
        script_run("screen -S newburn_KCOMPILE -X quit");
        script_run("rm -Rf /var/log/qa");

        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\n" | sort -t '-' > /tmp/rpmlist.after});
        upload_logs('/tmp/rpmlist.after');
    }
    else {
        die "Patch isn't needed";
    }
}

sub run {
    my $self  = shift;
    my $repo  = get_required_var('INCIDENT_REPO');
    my $patch = get_required_var('INCIDENT_PATCH');

    $self->wait_boot;
    select_console('root-console');

    if (check_var('KGRAFT', '1')) {
        my $qa_head = get_required_var('QA_HEAD_REPO');
        prepare_kgraft($repo, $patch);
        $self->wait_boot;
        select_console('root-console');

        # dependencies for heavy load script
        zypper_call("ar $qa_head qa_repo");
        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in qa_lib_ctcs2 qa_test_ltp qa_test_newburn");

        # update kgraft patch under heavy load
        update_kgraft($patch);

        zypper_call("rr qa_repo");
        zypper_call("rm qa_lib_ctcs2 qa_test_ltp qa_test_newburn");

        type_string("reboot\n");

        $self->wait_boot;
        select_console('root-console');

        kgraft_state;
    }
    else {
        update_kernel($repo, $patch);
    }

    type_string("reboot\n");
}

sub test_flags {
    return {fatal => 1};
}
1;
