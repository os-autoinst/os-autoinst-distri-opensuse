# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Monitor installation progress and wait for "reboot now" dialog
# - Inside a loop, run check_screen for each element of array @tags
# - Check return code of check_screen against array @tags
#   - If no return code, decreate timeout by 30s, print diagnose text: "left total await_install timeout: $timeout"
#   - If timeout less than 0, assert_screen on element of @tags and abort: "timeout hit on during await_install"
#   'installation not finished, move mouse around a bit to keep screen unlocked'
#   and move mouse to prevent screenlock
#   - If needle matches "yast_error", abort with 'YaST error detected. Test is terminated.'
#   - If needle matches 'yast2_wrong_digest', abort with 'Wrong Digest detected error, need to end test.'
#   - If needle matches 'yast2_package_retry', record_soft_failure 'boo#1018262
#   retry failing packages', send 'alt-y', retry in 4s, otherwise, abort with 'boo#1018262 - seems to be stuck on retry'
#   - If needle matches 'DIALOG-packages-notifications', send alt-o
#   - if needle matches 'ERROR-removing-package':
#     - Send 'alt-d', check for needle 'ERROR-removing-package-details'
#     - Send 'alt-i', check for needle 'WARNING-ignoring-package-failure'
#     - Send 'alt-o'
#   - If needle matches 'additional-packages'
#     - Send 'alt-i'
#   - If needle matches 'package-update-found'
#     - Send 'alt-n'
#   - Stop reboot timeout where necessary
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use lockapi;
use mmapi;
use utils;
use Utils::Architectures;
use Utils::Backends;
use version_utils qw(:VERSION :BACKEND is_sle is_leap is_sle_micro);
use ipmi_backend_utils;

# Stop countdown and check success by waiting screen change without performing an action
sub wait_countdown_stop {
    my ($stilltime, $similarity) = @_;
    send_key 'alt-s';
    return wait_screen_change(undef, $stilltime, similarity => $similarity);
}

sub _set_timeout {
    my ($timeout) = @_;
    # upgrades are slower
    ${$timeout} = 5500 if (get_var('UPGRADE') || get_var('LIVE_UPGRADE'));
    # our Hyper-V server is just too slow
    # SCC might mean we install everything from the slow internet
    ${$timeout} = 5500 if (check_var('VIRSH_VMM_FAMILY', 'hyperv') || (check_var('SCC_REGISTER', 'installation') && !get_var('SCC_URL')));
    # VMware server is also a bit slow, needs to take more time
    ${$timeout} = 3600 if (check_var('VIRSH_VMM_FAMILY', 'vmware'));

    # aarch64 can be particularily slow depending on the hardware
    ${$timeout} *= 2 if is_aarch64 && get_var('MAX_JOB_TIME');
    # PPC HMC (Power9) performs very slow in general
    ${$timeout} *= 2 if is_pvm_hmc && get_var('MAX_JOB_TIME');
    # encryption, LVM and RAID makes it even slower
    ${$timeout} *= 2 if (get_var('ENCRYPT') || get_var('LVM') || get_var('RAID'));
    # "allpatterns" tests install a lot of packages
    ${$timeout} *= 2 if check_var_array('PATTERNS', 'all');
    # multipath installations seem to take longer (failed some time)
    ${$timeout} *= 2 if check_var('MULTIPATH', 1);
    ${$timeout} *= 2 if get_var('USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL');

    # Reset timeout for migration group test cases
    if (get_var('FLAVOR') =~ /Migration/) {
        ${$timeout} = 5500;
        ${$timeout} += 2000 if is_s390x;
        if (get_var('FLAVOR') =~ /Regression/) {
            ${$timeout} *= 2 if is_s390x;
        }
    }

    # Scale timeout
    ${$timeout} *= get_var('TIMEOUT_SCALE', 1);
}

sub run {
    my $self = shift;
    # NET isos are slow to install
    # If this timeout needs to be bumped again, we might be having a bigger network problem
    # or a peformance problem on the installer
    my $timeout = (is_s390x || is_ppc64le) ? 2400 : 2000;

    # workaround for yast popups and
    # detect "Wrong Digest" error to end test earlier
    my @tags = qw(rebootnow yast2_wrong_digest yast2_package_retry yast_error initializing-target-directory-failed linuxrc_error);
    _set_timeout(\$timeout);
    if (get_var('UPGRADE') || get_var('LIVE_UPGRADE')) {
        push(@tags, 'ERROR-removing-package');
        push(@tags, 'DIALOG-packages-notifications');
        # There is a dialog with packages that updates are available from
        # the official repo, do not use those as want to use not published repos only
        push(@tags, 'package-update-found') if is_opensuse;
        # _timeout() adjusts the $timeout because upgrades are slower;
    }
    # on s390 we might need to install additional packages depending on the installation method
    if (is_s390x) {
        ssh_password_possibility();
        push(@tags, 'additional-packages');
    }
    # For poo#64228, we need ensure the timeout value less than the MAX_JOB_TIME
    my $max_job_time_bound = get_var('MAX_JOB_TIME', 7200) - 1000;
    record_info("Timeout exceeded", "Computed timeout '$timeout' exceeds max_job_time_bound '$max_job_time_bound', consider decreasing '$timeout' or increasing 'MAX_JOB_TIME'") if $timeout > $max_job_time_bound;

    my $mouse_x = 1;
    while (1) {
        die "timeout ($timeout) hit on during await_install" if $timeout <= 0;
        my $ret = check_screen \@tags, 30;
        $timeout -= 30;
        diag("left total await_install timeout: $timeout");
        if (!$ret) {
            if (get_var('LIVECD') || get_var('SUPPORT_SERVER')) {
                # The workaround with mouse moving was added, because screen
                # become disabled after some time without activity on aarch64.
                # Mouse is moved by 10 pixels, waited for 1 second (this is
                # needed because it seems like the move is too fast to be detected
                # on aarch64).
                diag('installation not finished, move mouse around a bit to keep screen unlocked');
                mouse_set(($mouse_x + 10) % 1024, 1);
                sleep 1;
                mouse_set($mouse_x, 1);
            }
            next;
        }
        if (match_has_tag("linuxrc_error")) {
            die 'Installation cant continue. Check medium or hardware.';
        }
        if (match_has_tag('yast_error')) {
            if (match_has_tag('yast_error_mkinitrd_armv7') && is_arm) {
                record_soft_failure 'boo#1171180 - mkinitrd broken on armv7';
                send_key 'alt-o';    # ok
                next;
            }
            else {
                die 'YaST error detected. Test is terminated.';
            }
        }

        if (match_has_tag('yast2_wrong_digest')) {
            die 'Wrong Digest detected error, need to end test.';
        }

        if (match_has_tag('yast2_package_retry')) {
            record_soft_failure 'boo#1018262 - retry failing packages';
            send_key 'alt-y';    # retry
            die 'boo#1018262 - seems to be stuck on retry' unless wait_screen_change { sleep 4 };
            next;
        }

        if (match_has_tag('DIALOG-packages-notifications')) {
            send_key 'alt-o';    # ok
            next;
        }
        # can happen multiple times
        if (match_has_tag('ERROR-removing-package')) {
            send_key 'alt-d';    # details
            assert_screen 'ERROR-removing-package-details';
            send_key 'alt-i';    # ignore
            assert_screen 'WARNING-ignoring-package-failure';
            send_key 'alt-o';    # ok
            next;
        }
        if (match_has_tag('additional-packages')) {
            send_key 'alt-i';
            next;
        }
        #
        if (match_has_tag 'package-update-found') {
            send_key 'alt-n';
            next;
        }
        # rpm cache failed to load
        if (match_has_tag 'initializing-target-directory-failed') {
            record_soft_failure "bsc#1182928 - Initializing the target directory failed";
            send_key 'alt-o';
            next;
        }
        last;
    }

    # Stop reboot countdown where necessary for e.g. uploading logs
    unless (check_var('REBOOT_TIMEOUT', 0) || get_var("REMOTE_CONTROLLER") || is_microos || (is_sle('=11-sp4') && is_s390x && is_backend_s390x)) {
        # Depending on the used backend the initial key press to stop the
        # countdown might not be evaluated correctly or in time. In these
        # cases we keep hitting the keys until the countdown stops.
        my $counter = 10;
        # A single changing digit is only a minor change, overide default
        # similarity level considered a screen change
        my $minor_change_similarity = 55;
        while ($counter-- and wait_countdown_stop(1, $minor_change_similarity)) {
            record_info('workaround', "While trying to stop countdown we saw a screen change, retrying up to $counter times more");
        }
    }
}

# Add password possibility for root on s390x because of poo#93949
sub ssh_password_possibility {
    if (!is_sle && !is_leap && !is_sle_micro) {
        select_console 'install-shell';
        assert_script_run('mountpoint /mnt && mkdir -p /mnt/etc/ssh/sshd_config.d');
        assert_script_run('echo PermitRootLogin yes > /mnt/etc/ssh/sshd_config.d/allow-root-with-password.conf');
        select_console 'installation';
    }
}

sub post_fail_hook {
    my ($self) = shift;
    # Collect y2log firstly for migration case since this is high priority
    # since sometimes error happen during default post_fail_hook
    if (get_var('FLAVOR') =~ /Migration/) {
        select_console 'root-console';
        assert_script_run 'save_y2logs /tmp/y2logs.tar.bz2';
        upload_logs '/tmp/y2logs.tar.bz2';
    }
    $self->SUPER::post_fail_hook;
}

1;
