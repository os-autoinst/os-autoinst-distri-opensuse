# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: smoke test for Live Patching in SLE Micro
#           1) Get current kernel version
#           2) Make sure the system has been registered previously
#           3) Register Live Patching module if not done already
#           4) Optionally add a kernel update repo
#           5) Update system and reboot
#           6) Get new kernel version and compare it
#
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional;
use utils qw(zypper_call ensure_ca_certificates_suse_installed);

sub register_lp_module {
    my $arch        = get_required_var('ARCH');
    my $regcode     = get_required_var('SCC_REGCODE');
    my $sle_version = get_required_var('VERSION_SLE');
    my $extensions  = script_output('SUSEConnect --list-extensions');
    record_info('Extensions', $extensions);
    unless ($extensions =~ m/Live Patching.*Activated/) {
        record_info('Register', 'Registering module "sle-module-live-patching"');
        trup_call("register -p sle-module-live-patching/$sle_version/$arch -r $regcode");
        check_reboot_changes;
        $extensions = script_output('SUSEConnect --list-extensions');
        record_info('SUSEConnect', script_output('SUSEConnect --status-text'));
        record_info('Extensions',  $extensions);
    }
    die('There was a problem activating the Live Patching module') unless ($extensions =~ m/Live Patching.*Activated/);
    zypper_call '--gpg-auto-import-keys ref';
}

sub configure_lp {
    # ensure sle-module-live-patching-release is installed
    assert_script_run('rpm -q sle-module-live-patching-release');
    if (script_output('zypper patterns --installed-only') !~ 'lp_sles') {
        record_info('Pattern', 'Installing pattern lp_sles');
        trup_call('pkg install -t pattern lp_sles');
        check_reboot_changes;
    }
    record_info('Install', 'Installing kernel-default-livepatch');
    trup_call('pkg install --oldpackage kernel-default-livepatch');
    check_reboot_changes;
    assert_script_run("sed -i 's/multiversion =.*/multiversion = provides:multiversion(kernel)/' /etc/zypp/zypp.conf");
    assert_script_run("sed -i \'s/multiversion.kernels =.*/multiversion.kernels = latest/g\' /etc/zypp/zypp.conf");
    assert_script_run("echo \"LIVEPATCH_KERNEL='always'\" > /etc/sysconfig/livepatching");
    upload_logs('/etc/zypp/zypp.conf',         failok => 1);
    upload_logs('/etc/sysconfig/livepatching', failok => 1);
}

sub setup_optional_repo {
    # Option to use a test repository with an existing kernel update.
    # This is useful if regular channels don't provide any kernel update
    # and we want to force testing this feature
    my $test_repo = get_var('SLE_MICRO_KERNEL_REPO');
    if ($test_repo) {
        ensure_ca_certificates_suse_installed;
        record_info('Repo', "Adding repository $test_repo");
        zypper_call "ar $test_repo";
        zypper_call '--gpg-auto-import-keys ref';
    }
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    # Get current kernel version
    my $kernel_version = script_output('uname -r');
    record_info('Kernel', $kernel_version);

    # Make sure the system has been registered previously
    my $reg_status = script_output('SUSEConnect --status-text');
    record_info('SUSEConnect', $reg_status);
    die('Register system before running this test module') if ($reg_status =~ /Not Registered/);

    # Preconfiguration before updating the tests
    $self->register_lp_module;
    $self->configure_lp;
    $self->setup_optional_repo;

    record_info('Update', 'Updating the system');
    trup_call('up');
    check_reboot_changes;

    # Get new kernel version
    my $new_kernel_version = script_output('uname -r');
    record_info('Kernel', $new_kernel_version);

    if ($kernel_version eq $new_kernel_version) {
        # The test shouldn't fail if there is no update, which won't be always the case
        record_info('RESULT', 'The kernel versions are the same after update.');
    }
    else {
        record_info('RESULT', 'The kernel has been successfully updated.');
    }
}

1;
