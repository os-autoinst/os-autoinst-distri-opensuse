# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Performed a "forkbomb" test on HANA
# Requires: sles4sap/wizard_hana_install, ENV variables INSTANCE_SID
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use version_utils qw(package_version_cmp);

sub run {
    my ($self) = @_;

    # NOTE: Do not call this function on the qemu backend
    # The first forkbomb can create 3 times as many processes as the second due to unknown bug
    return if is_qemu;

    select_serial_terminal;

    # The SAP Admin was set in sles4sap/wizard_hana_install
    my $sid = get_required_var('INSTANCE_SID');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sapadm = $self->set_sap_info($sid, $instance_id);

    my $package_version = script_output "rpm -q --qf '%{VERSION}' saptune";
    record_info('saptune version', $package_version);
    my $note_id = '2578899';
    my $conf_kernel_pid_max_old = script_output("grep kernel.pid_max /usr/share/saptune/notes/$note_id", proceed_on_failure => 1);
    record_info('Old conf value', $conf_kernel_pid_max_old);
    my $os_kernel_pid_max_old = script_output('sysctl -a | grep kernel.pid_max', proceed_on_failure => 1);
    record_info('Old kernel.pid_max', $os_kernel_pid_max_old);

    # Reset kernel.pid_max according to the changes of SAP Note 2578899
    # See https://github.com/SUSE/saptune/commit/a81168759681a05437e60429de0ddc1e19c703f4
    # Or see https://github.com/SUSE/saptune/releases/tag/3.1.3 for more details
    if (package_version_cmp($package_version, '3.1.3') >= 0) {
        my $pid_max = get_var('OPENQA_KERNEL_PID_MAX', 40000);
        # Do revert for this note as it was applied
        assert_script_run("saptune note revert $note_id");
        assert_script_run("cp /usr/share/saptune/notes/$note_id /etc/saptune/override/");
        assert_script_run("sed -i -r 's/^kernel.pid_max=.*/kernel.pid_max=$pid_max/g' /etc/saptune/override/$note_id");
        my $conf_kernel_pid_max_new
          = script_output("grep kernel.pid_max /etc/saptune/override/$note_id | cut -d '=' -f2 | tr -d ' '", proceed_on_failure => 1);
        record_info('New conf value', $conf_kernel_pid_max_new);
        assert_script_run("saptune note apply $note_id");
        my $os_kernel_pid_max_new = script_output("sysctl -a | grep kernel.pid_max | cut -d '=' -f2 | tr -d ' '", proceed_on_failure => 1);
        record_info('New kernel.pid_max', $os_kernel_pid_max_new);
        if ($os_kernel_pid_max_new != $conf_kernel_pid_max_new) {
            die "Error, os_kernel_pid_max_new != conf_kernel_pid_max_new: $os_kernel_pid_max_new != $conf_kernel_pid_max_new";
        }
    }

    $self->test_forkbomb;
}

1;
