# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nvme-cli
# Summary: Smoke tests for NVM Express.
#
# - Install nvme-cli which is a tool to manage NVM Express
# - Check sys path that should be hold details
# - Check if we have any NVMe controllers on the PCI bus
# - Check if we have NVMe devices
# - Check if we have namespace
# - Send Identify Admin Command to the NVMe controller
# - Issue a Read command both using the helper and manually
# - Compare it to what we have with a regular dd
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use scheduler 'get_test_suite_data';

sub _check_basic_installation {
    my $nvm_test_data = shift;
    assert_script_run("lspci -nn | grep -i nvm");
    assert_script_run("test -d $nvm_test_data->{nvme_sys_path}", fail_message => "$nvm_test_data->{nvme_sys_path} not found as block device");
    assert_script_run("test -c /dev/$nvm_test_data->{nvm_char_device}", fail_message => "/dev/$nvm_test_data->{nvme_char_device} not found as character device");

    my @nvm_partitions = split(/\n/, script_output("ls /dev/$nvm_test_data->{nvm_disk}*"));
    foreach (@nvm_partitions) {
        assert_script_run("test -b $_", fail_message => "$_ should be a block device");
    }
}

sub _exercise_nvme_commands_and_validate_output {
    my $nvm_test_data = shift;
    # send Identify Admin Command to the NVMe controller.
    assert_script_run("nvme id-ctrl -H /dev/$nvm_test_data->{nvm_char_device} > id_ctrl_output");
    record_info "Identify Admin Command Output", script_output("cat id_ctrl_output");
    my $MODE = '\/dev\/' . $nvm_test_data->{nvm_char_device};
    my $SN = $nvm_test_data->{sn};
    my $MODEL = $nvm_test_data->{model};
    my $NAMESPACE = $nvm_test_data->{namespace_count};
    my $DISK_SIZE = $nvm_test_data->{nvm_disk_size};
    my $BLOCK_SIZE = $nvm_test_data->{nvm_block_size};
    my $list_regex = qr/${MODE}\s+$SN\s+${MODEL}\s+${NAMESPACE}\s+${DISK_SIZE}\s+GB.*\d+\s+GB\s+${BLOCK_SIZE}/;
    validate_script_output("nvme list", sub { $list_regex });
    validate_script_output("nvme list-ns /dev/$nvm_test_data->{nvm_char_device} | awk -F ':' '{print $2}'", sub { /$nvm_test_data->{nvm_ns}/ });
    # the details of this namespace
    # check LBA Format fields
    # ms = Metadata Size, 0 means metadata is not supported
    # lbads = LBA Data Size, in terms of a power of two, so LBA data size is 2⁹ = 512 bytes
    # rp = Relative Performance, the lower the better
    validate_script_output("nvme id-ns /dev/$nvm_test_data->{nvm_disk} --namespace-id=$nvm_test_data->{nvm_ns}", sub { m/lbaf\s+0\s+:\s+ms:0\s+lbads:9\s+rp:0\s\(in use\)/ });
}

sub _issue_read_command_and_compare_with_dd {
    my $nvm_test_data = shift;
    assert_script_run("dd if=/dev/$nvm_test_data->{nvm_disk} of=lba.0.dd bs=512 count=1");
    # read LBA 0 through nvme utility
    assert_script_run("nvme read /dev/$nvm_test_data->{nvm_disk} --start-block=0 --block-count=0 --data-size=512 --data=lba.0.read");
    # Read is opcode 0x02, we are sending command to namespace 0x1, reading 512 bytes
    # code word 10 and 11 (cdw10 and cdw11) specifies the start of reading in LBA blocks,
    # and the Bits 15:00 of code word 12 (cdw12) is number of blocks to read (set to 0 to indicate 1 block will be read).
    assert_script_run("nvme io-passthru /dev/$nvm_test_data->{nvm_char_device} --opcode=0x02 --namespace-id=0x1 --data-len=512 --read --cdw10=0 --cdw11=0 --cdw12=0 -b > lba.0.io");
    assert_script_run("cmp lba.0.dd lba.0.read", fail_message => "The Admin read command is broken. Results are different between the helper read command and the manual dd");
    assert_script_run("cmp lba.0.dd lba.0.io", fail_message => "The Submission and Completion queue for Admin commands differs from I/O commands");
}

sub _check_nvme_tools_installed {
    my $ret = zypper_call('se -x -i nvme-cli', exitcode => [0, 104]);
    if ($ret == 104) {
        record_soft_failure "bsc#1172866 - nvme-cli is not installed";
        zypper_call("in nvme-cli");
    }
    record_info "nvme_cli found", "No installation is needed for nvme_cli" if ($ret == 0);
}

sub run {
    select_console 'root-console';
    my $testdata = get_test_suite_data();

    _check_nvme_tools_installed;
    _check_basic_installation($testdata);
    _exercise_nvme_commands_and_validate_output($testdata);
    _issue_read_command_and_compare_with_dd($testdata);
}

sub _collect_nvme_debug_info {
    my @tar_input_files;
    my %cmds = (
        nvme_admin_command_info => 'tar cvPf nmve_sys_class.tar /sys/class/nvme/',
        nvme_devices_list => 'ls -la /dev/vcme',
        nvme_devices_info => 'blkid',
        nvme_controller_info => 'lspci -nn',
        nvme_cli_version => 'rpm -qa nvme-cli'
    );

    foreach (keys %cmds) {
        assert_script_run "echo Executing $cmds{$_}: > /tmp/$_";
        assert_script_run "echo -------------------- >> /tmp/$_";
        script_run "$cmds{$_} >> /tmp/$_ 2>&1";
        push @tar_input_files, "/tmp/$_";
    }
    assert_script_run "tar cvf /tmp/nvme_troubleshoot.tar @tar_input_files";
    upload_logs('/tmp/nvme_troubleshoot.tar');
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook();
    _collect_nvme_debug_info;
}

1;
