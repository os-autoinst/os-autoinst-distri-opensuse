# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Some functions to run test for xfstests
# Maintainer: Yong Sun <yosun@suse.com>, Long An <lan@suse.com>
package xfstests_utils;

use base Exporter;
use Exporter;
use 5.018;
use strict;
use warnings;
use utils;
use testapi;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use Utils::Backends 'is_pvm';
use serial_terminal 'select_serial_terminal';
use power_action_utils qw(power_action prepare_system_shutdown);
use filesystem_utils qw(format_partition generate_xfstests_list);
use lockapi;
use mmapi;
use version_utils 'is_public_cloud';
use LTP::utils;
use LTP::WhiteList;
use bugzilla;

# Heartbeat variables, need to sync with tests/xfstests/run.pm
my $HB_PATN = '<h>';    #shorter label <heartbeat> to getting stable under heavy stress
my $HB_DONE = '<d>';    #shorter label <done> to getting stable under heavy stress
my $HB_DONE_FILE = '/opt/test.done';
my $HB_EXIT_FILE = '/opt/test.exit';
my $HB_SCRIPT = '/opt/heartbeat.sh';

# None heartbeat variables
my ($test_status, $test_start, $test_duration);

# General variables, need to sync with tests/xfstests/run.pm
my $TEST_WRAPPER = '/opt/wrapper.sh';
my $STATUS_LOG = '/opt/status.log';
my $INST_DIR = '/opt/xfstests';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $TEST_FOLDER = '/opt/test';
my $SCRATCH_FOLDER = '/opt/scratch';

our @EXPORT = qw(
  heartbeat_prepare
  heartbeat_start
  heartbeat_stop
  heartbeat_wait
  test_wait
  test_name
  log_add
  tests_from_category
  exclude_grouplist
  include_grouplist
  tests_from_ranges
  test_run
  save_kdump
  shuffle
  copy_log
  copy_fsxops
  dump_btrfs_img
  raw_dump
  collect_fs_status
  copy_all_log
  reload_loop_device
  umount_xfstests_dev
  config_debug_option
  test_run_without_heartbeat
  check_bugzilla_status);

=head2 heartbeat_prepare

Create heartbeat script and directories (Call it only once)

=cut

sub heartbeat_prepare {
    my $hb_intvl = shift;
    my $redir = " >> /dev/$serialdev";
    my $script = <<END_CMD;
#!/bin/sh
rm -f $HB_DONE_FILE $HB_EXIT_FILE
declare -i c=0
while [[ ! -f $HB_EXIT_FILE ]]; do
    if [[ -f $HB_DONE_FILE ]]; then
        c=0
        echo "$HB_DONE" $redir
        sleep 2
    elif [[ \$c -ge $hb_intvl ]]; then
        c=0
        echo "$HB_PATN" $redir
    else
        c+=1
    fi
    sleep 1
done
END_CMD
    assert_script_run("cat > $HB_SCRIPT <<'END'\n$script\nEND\n( exit \$?)");
}

=head2 heartbeat_start

Start heartbeat, setup environment variables (Call it everytime SUT reboots)

=cut

sub heartbeat_start {
    enter_cmd(". ~/.xfstests; nohup sh $HB_SCRIPT &");
}

=head2 heartbeat_stop

Stop heartbeat

=cut

sub heartbeat_stop {
    my $virtio_console = shift;
    ($virtio_console == 1) ? type_string "\n" : send_key 'ret';
    assert_script_run("touch $HB_EXIT_FILE");
}

=head2 heartbeat_wait

Wait for heartbeat

=cut

sub heartbeat_wait {
    # When under heavy load, the SUT might be unable to send
    # heartbeat messages to serial console. That's why HB_TIMEOUT
    # is set to 200 by default: waiting for such tests to finish.
    my ($hb_timeout, $virtio_console) = @_;
    my $ret = wait_serial([$HB_PATN, $HB_DONE], $hb_timeout);
    if ($ret) {
        if ($ret =~ /$HB_PATN/) {
            return ($HB_PATN, '');
        }
        else {
            my $status;
            ($virtio_console == 1) ? type_string "\n" : send_key 'ret';
            my $ret = script_output("cat $HB_DONE_FILE; rm -f $HB_DONE_FILE", 120, type_command => 1, proceed_on_failure => 1);
            $ret =~ s/^\s+|\s+$//g;
            if ($ret == 0) {
                $status = 'PASSED';
            }
            elsif ($ret == 22) {
                $status = 'SKIPPED';
            }
            else {
                $status = 'FAILED';
            }
            return ($HB_DONE, $status);
        }
    }
    return ('', 'FAILED');
}

=head2 test_wait

Wait for test to finish

=cut

sub test_wait {
    my ($subtest_timeout, $hb_timeout, $virtio_console) = @_;
    my $begin = time();
    my ($type, $status) = heartbeat_wait($hb_timeout, $virtio_console);
    my $delta = time() - $begin;
    # In case under heavy stress, only match first 2 words in label is enough
    my $hb_label = substr($HB_PATN, 0, 2);
    while ($type =~ /$hb_label/ and $delta < $subtest_timeout) {
        ($type, $status) = heartbeat_wait($hb_timeout, $virtio_console);
        $delta = time() - $begin;
    }
    if ($type eq $HB_PATN) {
        return ('', 'FAILED', $delta);
    }
    return ($type, $status, $delta);
}

=head2 test_name

Format the name of a subtest, because we don't want / to be seen like directory (e.g. xfs-005)
test - specific test (e.g. xfs/005)

=cut

sub test_name {
    my $test = shift;
    return $test =~ s/\//-/gr;
}

=head2 log_add

Add one test result to log file
file   - log file
test   - specific test (e.g. xfs/008)
status - test status
time   - time consumed

=cut

sub log_add {
    my ($file, $test, $status, $time) = @_;
    my $name = test_name($test);
    unless ($name and $status) { return; }
    my $cmd = "echo '$name ... ... $status (${time}s)' | tee -a $file";
    my $ret = script_output($cmd, 60, type_command => 1, proceed_on_failure => 1);
    return $ret;
}

=head2 tests_from_category

Return all the tests of a specific xfstests category
category - xfstests category (e.g. generic)
dir      - xfstests installation dir (e.g. /opt/xfstests)

=cut

sub tests_from_category {
    my ($category, $dir) = @_;
    my $cmd = "find '$dir/tests/$category' -regex '.*/[0-9]+'";
    my $output = script_output($cmd, 120, type_command => 1, proceed_on_failure => 1);
    my @tests = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
    }
    return @tests;
}

=head2 exclude_grouplist

Return matched exclude tests from groups in XFSTESTS_GROUPLIST
return structure - hash
Group name start with ! will exclude in test, and expected to use to update blacklist
If TEST_RANGES contain generic tests, then exclude tests from generic folder, else will exclude tests from filesystem type folder

=cut

sub exclude_grouplist {
    my ($test_ranges, $grouplist, $fstype) = @_;
    my %tests_list = ();
    return unless $grouplist;
    my $test_folder = $test_ranges =~ /generic/ ? "generic" : $fstype;
    my @group_list = split(/,/, $grouplist);
    foreach my $group_name (@group_list) {
        next if ($group_name !~ /^\!/);
        $group_name = substr($group_name, 1);
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group.list | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
        script_run($cmd);
        $cmd = "awk '/$group_name/' $INST_DIR/tests/$fstype/group.list | awk '{printf \"$fstype/\"}{printf \$1}{printf \",\"}' >> tmp.group";
        script_run($cmd) if ($test_folder eq "generic" and $test_ranges =~ /$fstype/);
        $cmd = "cat tmp.group";
        my %tmp_list = map { $_ => 1 } split(/,/, substr(script_output($cmd, 120, type_command => 1, proceed_on_failure => 1), 0, -1));
        %tests_list = (%tests_list, %tmp_list);
    }
    return %tests_list;
}

=head2 include_grouplist

Return matched include tests from groups in XFSTESTS_GROUPLIST
return structure - array
Group name start without ! will include in test, and expected to use to update test ranges
If TEST_RANGES contain generic tests, then include tests from generic folder, else will include tests from filesystem type folder

=cut

sub include_grouplist {
    my ($test_ranges, $grouplist, $fstype) = @_;
    my @tests_list;
    return unless $grouplist;
    my $test_folder = $test_ranges =~ /generic/ ? "generic" : $fstype;
    my @group_list = split(/,/, $grouplist);
    foreach my $group_name (@group_list) {
        next if ($group_name =~ /^\!/);
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group.list | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
        script_run($cmd);
        $cmd = "awk '/$group_name/' $INST_DIR/tests/$fstype/group.list | awk '{printf \"$fstype/\"}{printf \$1}{printf \",\"}' >> tmp.group";
        script_run($cmd) if ($test_folder eq "generic" and $test_ranges =~ /$fstype/);
        $cmd = "cat tmp.group";
        my $tests = substr(script_output($cmd, 120, type_command => 1, proceed_on_failure => 1), 0, -1);
        foreach my $single_test (split(/,/, $tests)) {
            push(@tests_list, $single_test);
        }
    }
    return @tests_list;
}

=head2 tests_from_ranges

Return a list of tests to run from given test ranges
ranges - test ranges (e.g. xfs/001-100,btrfs/100-159)
dir    - xfstests installation dir (e.g. /opt/xfstests)

=cut

sub tests_from_ranges {
    my ($ranges, $dir) = @_;
    if ($ranges !~ /\w+(\/\d+-\d+)?(,\w+(\/\d+-\d+)?)*/) {
        die "Invalid test ranges: $ranges";
    }
    my %cache;
    my @tests;
    foreach my $range (split(/,/, $ranges)) {
        my ($min, $max) = (0, 99999);
        my ($category, $min_max) = split(/\//, $range);
        unless (defined($min_max)) {
            next;
        }
        if ($min_max =~ /\d+-\d+/) {
            ($min, $max) = split(/-/, $min_max);
        }
        else {
            $min = $max = $min_max;
        }
        unless (exists($cache{$category})) {
            $cache{$category} = [tests_from_category($category, $dir)];
            assert_script_run("mkdir -p $LOG_DIR/$category");
        }
        foreach my $num (@{$cache{$category}}) {
            if ($num >= $min and $num <= $max) {
                push(@tests, "$category/$num");
            }
        }
    }
    return @tests;
}

=head2 test_run

# Run a single test and write log to file
# test - test to run (e.g. xfs/001)

=cut

sub test_run {
    my ($test, $fstype, $inject_info) = @_;
    my ($category, $num) = split(/\//, $test);
    my $run_options = '';
    if ($fstype =~ 'nfs') {
        $run_options = '-nfs';
    }
    elsif ($fstype =~ 'overlay') {
        $run_options = '-overlay';
    }
    my $cmd = "\n$TEST_WRAPPER '$test' $run_options $inject_info | tee $LOG_DIR/$category/$num; ";
    $cmd .= "echo \${PIPESTATUS[0]} > $HB_DONE_FILE\n";
    type_string($cmd);
}

=head2 save_kdump

Save kdump data for further uploading
test   - corresponding test(e.g. xfs/009)
dir    - Save kdump data to this dir
vmcore - include vmcore file
kernel - include kernel

=cut

sub save_kdump {
    my ($test, $dir, %args) = @_;
    $args{vmcore} ||= 0;
    $args{kernel} ||= 0;
    $args{debug} ||= 0;
    my $name = test_name($test);
    my $ret = script_run("mv /var/crash/* $dir/$name");
    if ($args{debug}) {
        $ret += script_run("if [ -e /usr/lib/debug/boot ]; then tar zcvf $dir/$name/vmcore-debug.tar.gz --absolute-names /usr/lib/debug/boot; fi");
    }
    return 0 if $ret != 0;

    my $removed = "";
    unless ($args{vmcore}) {
        $removed .= " $dir/$name/vmcore";
    }
    unless ($args{kernel}) {
        $removed .= " $dir/$name/*.{gz,bz2,xz}";
    }
    if ($removed) {
        assert_script_run("rm -f $removed");
    }
    return 1;
}

=head2 shuffle

mess up the order of test queue

=cut

sub shuffle {
    my @arr = @_;
    srand(time());
    for (my $i = $#arr; $i > 0; $i--) {
        my $j = int(rand($i + 1));
        ($arr[$i], $arr[$j]) = ($arr[$j], $arr[$i]);
    }
    return @arr;
}

=head2 copy_log

Log & Must included: Copy log to ready to save

=cut

sub copy_log {
    my ($category, $num, $log_type) = @_;
    my $cmd = "if [ -e /opt/xfstests/results/$category/$num.$log_type ]; then cat /opt/xfstests/results/$category/$num.$log_type | tee $LOG_DIR/$category/$num.$log_type; fi";
    script_run($cmd);
}

=head2 copy_fsxops

Log: Copy junk.fsxops for fails fsx tests included in subtests

=cut

sub copy_fsxops {
    my ($category, $num) = @_;
    my $cmd = "if [ -e $TEST_FOLDER/junk.fsxops ]; then cp $TEST_FOLDER/junk.fsxops $LOG_DIR/$category/$num.junk.fsxops; fi";
    script_run($cmd);
}

=head2 raw_dump

Log: Raw dump from SCRATCH_DEV via dd

=cut

sub raw_dump {
    my ($category, $num, $scratch_dev, $scratch_dev_pool) = @_;
    my $dev = $scratch_dev ? $scratch_dev : (split(/ /, $scratch_dev_pool))[0];
    assert_script_run("umount $dev;dd if=$dev of=$LOG_DIR/$category/$num.raw bs=512 count=1000");
}

=head2 collect_fs_status

Log: Collect fs runtime status for XFS, Btrfs and Ext4

=cut

sub collect_fs_status {
    my ($category, $num, $fstype, $is_crash) = @_;
    return if $is_crash;
    my $cmd;
    unless ($fstype eq 'nfs') {
        script_run('mount $TEST_DEV $TEST_DIR &> /dev/null');
        script_run("[ -n \"\$SCRATCH_DEV\" ] && mount \$SCRATCH_DEV $SCRATCH_FOLDER &> /dev/null");
    }
    if ($fstype eq 'xfs') {
        $cmd = <<END_CMD;
find /sys/fs/$fstype/ -type f -exec tail -n +1 {} + >> $LOG_DIR/$category/$num.fs_stat
xfs_info $TEST_FOLDER >> $LOG_DIR/$category/$num.xfsinfo
xfs_info $SCRATCH_FOLDER >> $LOG_DIR/$category/$num.xfsinfo
END_CMD
    }
    elsif ($fstype eq 'btrfs') {
        $cmd = "find /sys/fs/$fstype/*/allocation/ -type f -exec tail -n +1 {} + >> $LOG_DIR/$category/$num.fs_stat";
    }
    elsif ($fstype eq 'ext4') {
        $cmd = "find /sys/fs/$fstype/ -type f -exec tail -n +1 {} + >> $LOG_DIR/$category/$num.fs_stat";
    }
    elsif ($fstype eq 'nfs') {
        enter_cmd("$cmd");
        return;
    }
    $cmd .= <<END_CMD;
umount \$TEST_DEV &> /dev/null
[ -n "\$SCRATCH_DEV" ] && umount \$SCRATCH_DEV &> /dev/null
END_CMD
    enter_cmd("$cmd");
    record_info('fs_stat log', script_output("find $LOG_DIR/$category/ -name $num.fs_stat -type f -exec cat {} +", 120, type_command => 1, proceed_on_failure => 1));
}

=head2 copy_all_log

Add all above logs

=cut

sub copy_all_log {
    my ($category, $num, $fstype, $raw_dump, $scratch_dev, $scratch_dev_pool, $is_crash) = @_;
    copy_log($category, $num, 'out.bad');
    copy_log($category, $num, 'full');
    copy_log($category, $num, 'dmesg');
    copy_fsxops($category, $num);
    if (script_run("ls /opt/xfstests/results/$category/$num.*.md* 1> /dev/null 2>&1") == 0) {
        script_run("tar -cf $LOG_DIR/$num.dump.tar /opt/xfstests/results/$category/$num.*.md*");
        upload_logs("$LOG_DIR/$num.dump.tar");
    }
    collect_fs_status($category, $num, $fstype, $is_crash);
    if ($raw_dump) { raw_dump($category, $num, $scratch_dev, $scratch_dev_pool); }
}

=head2 reload_loop_device

Reload loop device for xfstests

=cut

sub reload_loop_device {
    my ($self, $fstype) = @_;
    assert_script_run("losetup -fP $INST_DIR/test_dev");
    my $scratch_amount = script_output("ls $INST_DIR/scratch_dev* | wc -l", 60, type_command => 1, proceed_on_failure => 1);
    my $scratch_num = 1;
    while ($scratch_amount >= $scratch_num) {
        assert_script_run("losetup -fP $INST_DIR/scratch_dev$scratch_num", 300);
        $scratch_num += 1;
    }
    script_run('losetup -a');
    format_partition("$INST_DIR/test_dev", $fstype);
}

=head2 umount_xfstests_dev

Umount TEST_DEV and SCRATCH_DEV

=cut

sub umount_xfstests_dev {
    my ($test_dev, $scratch_dev, $scratch_dev_pool) = @_;
    script_run("umount $test_dev &> /dev/null") if $test_dev;
    script_run("umount $scratch_dev &> /dev/null") if $scratch_dev;
    if ($scratch_dev_pool) {
        script_run("umount $_ &> /dev/null") foreach (split ' ', $scratch_dev_pool);
    }
}

=head2 config_debug_option

Enable softlockup panic collection and could manually enable other setting by XFSTESTS_DEBUG

=cut

sub config_debug_option {
    my $debug_info = shift;
    script_run('echo 1 > /proc/sys/kernel/softlockup_all_cpu_backtrace');    # on detection capture more debug information
    script_run('echo 1 > /proc/sys/kernel/softlockup_panic');    # panic when softlockup
    if ($debug_info) {
        # e.g. XFSTESTS_DEBUG could be one or more parameter in following
        # [hardlockup_panic hung_task_panic panic_on_io_nmi panic_on_oops panic_on_rcu_stall...]
        script_run("echo 1 > /proc/sys/kernel/$_ ") foreach (split ' ', $debug_info);
    }
}

=head2 test_run_without_heartbeat

Run a single test and write log to file but without heartbeat, return log_add output

=cut

sub test_run_without_heartbeat {
    my ($self, $test, $timeout, $fstype, $raw_dump, $scratch_dev, $scratch_dev_pool, $inject_info, $loop_device, $enable_kdump, $virtio_console, $get_log_content, $cloud_instance) = @_;
    my ($category, $num) = split(/\//, $test);
    my $run_options = '';
    my $status_num = 1;
    if ($fstype =~ /nfs/) {
        $run_options = '-nfs';
    }
    elsif ($fstype =~ /overlay/) {
        $run_options = '-overlay';
    }
    eval {
        $test_start = time();
        # Send kill signal 3 seconds after sending the default SIGTERM to avoid some tests refuse to stop after timeout
        assert_script_run("timeout -k 3 " . ($timeout - 5) . " $TEST_WRAPPER '$test' $run_options $inject_info | tee $LOG_DIR/$category/$num; echo \${PIPESTATUS[0]} > $LOG_DIR/subtest_result_num", $timeout);
        $test_duration = time() - $test_start;
    };
    if ($@) {
        $test_status = 'FAILED';
        $test_duration = time() - $test_start;
        script_run('rm -rf /tmp/*', timeout => 90);    # Get some space and inode for no-space-left-on-device error to get reboot signal
        sleep 2;
        copy_all_log($category, $num, $fstype, $raw_dump, $scratch_dev, $scratch_dev_pool, 1);

        if (is_public_cloud) {
            $cloud_instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
        }
        else {
            prepare_system_shutdown;
            reset_consoles if check_var('DESKTOP', 'textmode');
            ($virtio_console == 1) ? power_action('reboot') : send_key 'alt-sysrq-b';
            reconnect_mgmt_console if is_pvm;
            check_var('DESKTOP', 'textmode') ? $self->wait_boot_textmode : $self->wait_boot;
            select_serial_terminal();
        }
        # Save kdump data to KDUMP_DIR if not set "NO_KDUMP=1"
        if ($enable_kdump) {
            unless (save_kdump($test, $KDUMP_DIR, vmcore => 1, kernel => 1, debug => 1)) {
                # If no kdump data found, write warning to log
                my $msg = "Warning: $test crashed SUT but has no kdump data";
                script_run("echo '$msg' >> $LOG_DIR/$category/$num");
            }
        }

        # Reload loop device after a reboot
        reload_loop_device($self, $fstype) if $loop_device;
    }
    else {
        $status_num = script_output("tail -n 1 $LOG_DIR/subtest_result_num", 120, type_command => 1, proceed_on_failure => 1);
        $status_num =~ s/^\s+|\s+$//g;
        if ($status_num == 0) {
            $test_status = 'PASSED';
        }
        elsif ($status_num == 22) {
            $test_status = 'SKIPPED';
        }
        else {
            $test_status = 'FAILED';
            copy_all_log($category, $num, $fstype, $raw_dump, $scratch_dev, $scratch_dev_pool, 0);
        }
    }
    # Add test status to STATUS_LOG file
    if ($get_log_content) {
        return log_add($STATUS_LOG, $test, $test_status, $test_duration);
    }
    else {
        log_add($STATUS_LOG, $test, $test_status, $test_duration);
        my $log_content = script_output("cat $LOG_DIR/subtest_result_num", 120, type_command => 1, proceed_on_failure => 1);
        my $targs = {
            name => $test,
            status => $test_status,
            time => $test_duration,
            output => $log_content,
        };
        return $targs;
    }
}

=head2 check_bugzilla_status

A function use in white list, to check bugzilla status and write messages in output

=cut

sub check_bugzilla_status {
    my ($entry, $targs) = @_;
    if (exists $entry->{bugzilla}) {
        my $info = bugzilla_buginfo($entry->{bugzilla});

        if (!defined($info) || !exists $info->{bug_status}) {
            $targs->{bugzilla} = "Bugzilla error:\n" .
              "Failed to query bug #$entry->{bugzilla} status";
            return;
        }

        if ($info->{bug_status} =~ /resolved/i || $info->{bug_status} =~ /verified/i) {
            $targs->{bugzilla} = "Bug closed:\n" .
              "Bug #$entry->{bugzilla} is closed, ignoring whitelist entry";
            return;
        }
    }
    $targs->{status} = 'SOFTFAILED' unless $entry->{keep_fail};
    $targs->{failinfo} = $entry->{message};
}

1;
