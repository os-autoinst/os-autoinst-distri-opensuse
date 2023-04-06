# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: xfsprogs
# Summary: Run tests
# - Shuffle the list of xfs tests to run
# - Create heartbeat script, directorie
# - Start heartbeat, setup environment variables
# - Start test from list, write log to file
# - Collect test log and system logs
# - Check if SUT crashed, reset if necessary
# - Save kdump data, unless NO_KDUMP is set to 1
# - Stop heartbeat after last test on list
# - Collect all logs
# Maintainer: Yong Sun <yosun@suse.com>
package run;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use Utils::Backends 'is_pvm';
use power_action_utils qw(power_action prepare_system_shutdown);
use filesystem_utils qw(format_partition);

# Heartbeat variables
my $HB_INTVL = get_var('XFSTESTS_HEARTBEAT_INTERVAL') || 30;
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT') || 200;
my $HB_PATN = '<h>';    #shorter label <heartbeat> to getting stable under heavy stress
my $HB_DONE = '<d>';    #shorter label <done> to getting stable under heavy stress
my $HB_DONE_FILE = '/opt/test.done';
my $HB_EXIT_FILE = '/opt/test.exit';
my $HB_SCRIPT = '/opt/heartbeat.sh';

# xfstests variables
# - XFSTESTS_RANGES: Set sub tests ranges. e.g. XFSTESTS_RANGES=xfs/100-199 or XFSTESTS_RANGES=generic/010,generic/019,generic/038
# - XFSTESTS_BLACKLIST: Set sub tests not run in XFSTESTS_RANGES. e.g. XFSTESTS_BLACKLIST=generic/010,generic/019,generic/038
# - XFSTESTS_GROUPLIST: Include/Exclude tests in group(a classification by upstream). e.g. XFSTESTS_GROUPLIST='auto,!dangerous_online_repair'
# - XFSTESTS_SUBTEST_MAXTIME: Debug use. To set the max time to wait for sub test to finish. Meet this time frame will trigger reboot, and continue next tests.
# - XFSTESTS: TEST_DEV type, and test in this folder and generic/ folder will be triggered. XFSTESTS=(xfs|btrfs|ext4)
my $TEST_RANGES = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/opt/wrapper.sh';
my %BLACKLIST = map { $_ => 1 } split(/,/, get_var('XFSTESTS_BLACKLIST'));
my @GROUPLIST = split(/,/, get_var('XFSTESTS_GROUPLIST'));
my $STATUS_LOG = '/opt/status.log';
my $INST_DIR = '/opt/xfstests';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $MAX_TIME = get_var('XFSTESTS_SUBTEST_MAXTIME') || 2400;
my $FSTYPE = get_required_var('XFSTESTS');

# Create heartbeat script, directories(Call it only once)
sub test_prepare {
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
    elif [[ \$c -ge $HB_INTVL ]]; then
        c=0
        echo "$HB_PATN" $redir
    else
        c+=1
    fi
    sleep 1
done
END_CMD
    assert_script_run("cat > $HB_SCRIPT <<'END'\n$script\nEND\n( exit \$?)");
    assert_script_run("mkdir -p $KDUMP_DIR $LOG_DIR");
}

# Start heartbeat, setup environment variables(Call it everytime SUT reboots)
sub heartbeat_start {
    enter_cmd(". ~/.xfstests; nohup sh $HB_SCRIPT &");
}

# Stop heartbeat
sub heartbeat_stop {
    send_key 'ret';
    assert_script_run("touch $HB_EXIT_FILE");
}

# Wait for heartbeat
sub heartbeat_wait {
    # When under heavy load, the SUT might be unable to send
    # heartbeat messages to serial console. That's why HB_TIMEOUT
    # is set to 200 by default: waiting for such tests to finish.
    my $ret = wait_serial([$HB_PATN, $HB_DONE], $HB_TIMEOUT);
    if ($ret) {
        if ($ret =~ /$HB_PATN/) {
            return ($HB_PATN, '');
        }
        else {
            my $status;
            send_key 'ret';
            my $ret = script_output("cat $HB_DONE_FILE; rm -f $HB_DONE_FILE");
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

# Wait for test to finish
sub test_wait {
    my $timeout = shift;
    my $begin = time();
    my ($type, $status) = heartbeat_wait;
    my $delta = time() - $begin;
    # In case under heavy stress, only match first 2 words in label is enough
    my $hb_label = substr($HB_PATN, 0, 2);
    while ($type =~ /$hb_label/ and $delta < $timeout) {
        ($type, $status) = heartbeat_wait;
        $delta = time() - $begin;
    }
    if ($type eq $HB_PATN) {
        return ('', 'FAILED', $delta);
    }
    return ($type, $status, $delta);
}

# Return the name of a test(e.g. xfs-005)
# test - specific test(e.g. xfs/005)
sub test_name {
    my $test = shift;
    return $test =~ s/\//-/gr;
}

# Add one test result to log file
# file   - log file
# test   - specific test(e.g. xfs/008)
# status - test status
# time   - time consumed
sub log_add {
    my ($file, $test, $status, $time) = @_;
    my $name = test_name($test);
    unless ($name and $status) { return; }
    my $cmd = "echo '$name ... ... $status (${time}s)' >> $file && sync $file";
    send_key 'ret';
    assert_script_run($cmd);
    sleep 5;
    my $ret = script_output("cat $file", 60);
    return $ret;
}

# Return all the tests of a specific xfstests category
# category - xfstests category(e.g. generic)
# dir      - xfstests installation dir(e.g. /opt/xfstests)
sub tests_from_category {
    my ($category, $dir) = @_;
    my $cmd = "find '$dir/tests/$category' -regex '.*/[0-9]+'";
    my $output = script_output($cmd, 60);
    my @tests = split(/\n/, $output);
    foreach my $test (@tests) {
        $test = basename($test);
    }
    return @tests;
}

# Return matched exclude tests from groups in @GROUPLIST
# return structure - hash
# Group name start with ! will exclude in test, and expected to use to update blacklist
# If TEST_RANGES contain generic tests, then exclude tests from generic folder, else will exclude tests from filesystem type folder
sub exclude_grouplist {
    my %tests_list = ();
    my $test_folder = $TEST_RANGES =~ /generic/ ? "generic" : $FSTYPE;
    foreach my $group_name (@GROUPLIST) {
        next if ($group_name !~ /^\!/);
        $group_name = substr($group_name, 1);
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group.list | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
        script_run($cmd);
        $cmd = "cat tmp.group";
        my %tmp_list = map { $_ => 1 } split(/,/, substr(script_output($cmd), 0, -1));
        %tests_list = (%tests_list, %tmp_list);
    }
    return %tests_list;
}

# Return matched include tests from groups in @GROUPLIST
# return structure - array
# Group name start without ! will include in test, and expected to use to update test ranges
# If TEST_RANGES contain generic tests, then include tests from generic folder, else will include tests from filesystem type folder
sub include_grouplist {
    my @tests_list;
    my $test_folder = $TEST_RANGES =~ /generic/ ? "generic" : $FSTYPE;
    foreach my $group_name (@GROUPLIST) {
        next if ($group_name =~ /^\!/);
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group.list | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
        script_run($cmd);
        $cmd = "cat tmp.group";
        my $tests = substr(script_output($cmd), 0, -1);
        foreach my $single_test (split(/,/, $tests)) {
            push(@tests_list, $single_test);
        }
    }
    return @tests_list;
}

# Return a list of tests to run from given test ranges
# ranges - test ranges(e.g. xfs/001-100,btrfs/100-159)
# dir    - xfstests installation dir(e.g. /opt/xfstests)
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

# Run a single test and write log to file
# test - test to run(e.g. xfs/001)
sub test_run {
    my $test = shift;
    my ($category, $num) = split(/\//, $test);
    my $run_options = '';
    $run_options = '-nfs' if check_var('XFSTESTS', 'nfs');
    my $inject_code = get_var('INJECT_INFO', '');
    my $cmd = "\n$TEST_WRAPPER '$test' $run_options $inject_code | tee $LOG_DIR/$category/$num; ";
    $cmd .= "echo \${PIPESTATUS[0]} > $HB_DONE_FILE\n";
    type_string($cmd);
}

# Save kdump data for further uploading
# test   - corresponding test(e.g. xfs/009)
# dir    - Save kdump data to this dir
# vmcore - include vmcore file
# kernel - include kernel
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

# Kunth shuffle
sub shuffle {
    my @arr = @_;
    srand(time());
    for (my $i = $#arr; $i > 0; $i--) {
        my $j = int(rand($i + 1));
        ($arr[$i], $arr[$j]) = ($arr[$j], $arr[$i]);
    }
    return @arr;
}

# Log & Must included: Copy log to ready to save
sub copy_log {
    my ($category, $num, $log_type) = @_;
    my $cmd = "if [ -e /opt/xfstests/results/$category/$num.$log_type ]; then cat /opt/xfstests/results/$category/$num.$log_type | tee $LOG_DIR/$category/$num.$log_type; fi";
    script_run($cmd);
}

# Log: Copy junk.fsxops for fails fsx tests included in subtests
sub copy_fsxops {
    my ($category, $num) = @_;
    my $cmd = "if [ -e /mnt/test/junk.fsxops ]; then cp /mnt/test/junk.fsxops $LOG_DIR/$category/$num.junk.fsxops; fi";
    script_run($cmd);
}

# Log: Only run in test Btrfs, collect image dump for inconsistent error
sub dump_btrfs_img {
    my ($category, $num) = @_;
    my $cmd = "echo \"no inconsistent error, skip btrfs image dump\"";
    my $ret = script_output("grep -E -m 1 \"filesystem on .+ is inconsistent\" $LOG_DIR/$category/$num");
    if ($ret =~ /filesystem on (.+) is inconsistent/) { $cmd = "umount $1;btrfs-image $1 $LOG_DIR/$category/$num.img"; }
    script_run($cmd);
}

# Log: Raw dump from SCRATCH_DEV via dd
sub raw_dump {
    my ($category, $num) = @_;
    my $dev = get_var('XFSTESTS_SCRATCH_DEV') ? get_var('XFSTESTS_SCRATCH_DEV') : (split(/ /, get_var("XFSTESTS_SCRATCH_DEV_POOL")))[0];
    assert_script_run("umount $dev;dd if=$dev of=$LOG_DIR/$category/$num.raw bs=512 count=1000");
}

# Log: Collect fs runtime status for XFS, Btrfs and Ext4
sub collect_fs_status {
    my ($category, $num) = @_;
    my $cmd = <<END_CMD;
mount \$TEST_DEV \$TEST_DIR &> /dev/null
[ -n "\$SCRATCH_DEV" ] && mount \$SCRATCH_DEV /mnt/scratch &> /dev/null
END_CMD
    if ($FSTYPE eq 'xfs') {
        $cmd = <<END_CMD;
$cmd
echo "==> /sys/fs/$FSTYPE/stats/stats <==" > $LOG_DIR/$category/$num.fs_stat
cat /sys/fs/$FSTYPE/stats/stats >> $LOG_DIR/$category/$num.fs_stat
tail -n +1 /sys/fs/$FSTYPE/*/log/* >> $LOG_DIR/$category/$num.fs_stat
tail -n +1 /sys/fs/$FSTYPE/*/stats/stats >> $LOG_DIR/$category/$num.fs_stat
xfs_info /mnt/test > $LOG_DIR/$category/$num.xfsinfo
xfs_info /mnt/scratch >> $LOG_DIR/$category/$num.xfsinfo
END_CMD
    }
    elsif ($FSTYPE eq 'btrfs') {
        $cmd = <<END_CMD;
$cmd
tail -n +1 /sys/fs/$FSTYPE/*/allocation/data/[bdft]* >> $LOG_DIR/$category/$num.fs_stat
tail -n +1 /sys/fs/$FSTYPE/*/allocation/metadata/[bdft]* >> $LOG_DIR/$category/$num.fs_stat
tail -n +1 /sys/fs/$FSTYPE/*/allocation/metadata/dup/* >> $LOG_DIR/$category/$num.fs_stat
tail -n +1 /sys/fs/$FSTYPE/*/allocation/*/single/* >> $LOG_DIR/$category/$num.fs_stat
END_CMD
    }
    elsif ($FSTYPE eq 'ext4') {
        $cmd = <<END_CMD;
$cmd
tail -n +1 /sys/fs/$FSTYPE/*/* >> $LOG_DIR/$category/$num.fs_stat
END_CMD
    }
    $cmd = <<END_CMD;
$cmd
umount \$TEST_DEV &> /dev/null
[ -n "\$SCRATCH_DEV" ] && umount \$SCRATCH_DEV &> /dev/null
END_CMD
    enter_cmd("$cmd");
}

sub reload_loop_device {
    my $self = shift;
    assert_script_run("losetup -fP $INST_DIR/test_dev");
    my $scratch_amount = script_output("ls $INST_DIR/scratch_dev* | wc -l");
    my $scratch_num = 1;
    while ($scratch_amount >= $scratch_num) {
        assert_script_run("losetup -fP $INST_DIR/scratch_dev$scratch_num", 300);
        $scratch_num += 1;
    }
    script_run('losetup -a');
    format_partition("$INST_DIR/test_dev", $FSTYPE);
}

# Umount TEST_DEV and SCRATCH_DEV
sub umount_xfstests_dev {
    script_run('umount ' . get_var('XFSTESTS_TEST_DEV') . ' &> /dev/null') if get_var('XFSTESTS_TEST_DEV');
    script_run('umount ' . get_var('XFSTESTS_SCRATCH_DEV') . ' &> /dev/null') if get_var('XFSTESTS_SCRATCH_DEV');
    if (get_var('XFSTESTS_SCRATCH_DEV_POOL')) {
        script_run("umount $_ &> /dev/null") foreach (split ' ', get_var('XFSTESTS_SCRATCH_DEV_POOL'));
    }
}

sub config_debug_option {
    script_run('echo 1 > /proc/sys/kernel/softlockup_all_cpu_backtrace');    # on detection capture more debug information
    script_run('echo 1 > /proc/sys/kernel/softlockup_panic');    # panic when softlockup
    if (get_var('XFSTESTS_DEBUG')) {
        # e.g. XFSTESTS_DEBUG could be one or more parameter in following
        # [hardlockup_panic hung_task_panic panic_on_io_nmi panic_on_oops panic_on_rcu_stall...]
        script_run("echo 1 > /proc/sys/kernel/$_ ") foreach (split ' ', get_var('XFSTESTS_DEBUG'));
    }
}

sub run {
    my $self = shift;
    select_console('root-console');

    config_debug_option;

    # Get wrapper
    assert_script_run("curl -o $TEST_WRAPPER " . data_url('xfstests/wrapper.sh'));
    assert_script_run("chmod a+x $TEST_WRAPPER");

    # Get test list
    my @tests = tests_from_ranges($TEST_RANGES, $INST_DIR);
    my %uniq;
    @tests = (@tests, include_grouplist);
    @tests = grep { ++$uniq{$_} < 2; } @tests;

    # Shuffle tests list
    unless (get_var('NO_SHUFFLE')) {
        @tests = shuffle(@tests);
    }

    # Maintain BLACKLIST by exclude group list
    my %tests_needto_exclude = exclude_grouplist;
    %BLACKLIST = (%BLACKLIST, %tests_needto_exclude);

    test_prepare;
    heartbeat_start;
    my $status_log_content = "";
    foreach my $test (@tests) {
        # trim testname
        $test =~ s/^\s+|\s+$//g;
        # Skip tests inside blacklist
        if (exists($BLACKLIST{$test})) {
            next;
        }

        umount_xfstests_dev;

        # Run test and wait for it to finish
        my ($category, $num) = split(/\//, $test);
        enter_cmd("echo $test > /dev/$serialdev");
        test_run($test);
        my ($type, $status, $time) = test_wait($MAX_TIME);
        if ($type eq $HB_DONE) {
            # Test finished without crashing SUT
            $status_log_content = log_add($STATUS_LOG, $test, $status, $time);
            if ($status =~ /FAILED/) {
                copy_log($category, $num, 'out.bad');
                copy_log($category, $num, 'full');
                copy_log($category, $num, 'dmesg');
                copy_fsxops($category, $num);
                collect_fs_status($category, $num);
                if (get_var('BTRFS_DUMP', 0) && (check_var 'XFSTESTS', 'btrfs')) { dump_btrfs_img($category, $num); }
            }
            if (get_var('RAW_DUMP', 0)) { raw_dump($category, $num); }
            next;
        }

        # SUT crashed. Wait for kdump to finish.
        # After that, SUT will reboot automatically
        eval {
            power_action('reboot', keepconsole => is_pvm);
            reconnect_mgmt_console if is_pvm;
            $self->wait_boot;
        };
        # If SUT didn't reboot for some reason, force reset
        if ($@) {
            prepare_system_shutdown;
            select_console 'root-console' unless is_pvm;
            send_key 'alt-sysrq-b';
            reconnect_mgmt_console if is_pvm;
            $self->wait_boot;
        }

        sleep(1);
        select_console('root-console');
        # Save kdump data to KDUMP_DIR if not set "NO_KDUMP=1"
        unless (check_var('NO_KDUMP', '1')) {
            unless (save_kdump($test, $KDUMP_DIR, vmcore => 1, kernel => 1, debug => 1)) {
                # If no kdump data found, write warning to log
                my $msg = "Warning: $test crashed SUT but has no kdump data";
                script_run("echo '$msg' >> $LOG_DIR/$category/$num");
            }
        }

        # Add test status to STATUS_LOG file
        log_add($STATUS_LOG, $test, $status, $time);

        # Reload loop device after a reboot
        if (get_var('XFSTESTS_LOOP_DEVICE')) {
            reload_loop_device;
        }

        # Prepare for the next test
        heartbeat_start;

    }
    heartbeat_stop;

    #Save status log before next step(if run.pm fail will load into a last good snapshot)
    save_tmp_file('status.log', $status_log_content);
    my $local_file = "/tmp/opt_logs.tar.gz";
    my $back_pid = background_script_run("tar zcvf $local_file --absolute-names /opt/log/");
    script_run("wait $back_pid");
    upload_logs($local_file, failok => 1, timeout => 180);
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    my ($self) = shift;
    # Collect executed test logs
    my $back_pid = background_script_run('tar zcvf /tmp/opt_logs.tar.gz --absolute-names /opt/log/');
    script_run("wait $back_pid");
    upload_logs('/tmp/opt_logs.tar.gz', failok => 1, timeout => 180);
}

1;
