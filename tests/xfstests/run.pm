# SUSE's openQA tests
#
# Copyright © 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: xfsprogs
# Summary: Run tests
# - Shuffle the list of xfs tests to run
# - Start test from list, write log to file
# - Collect test log and system logs
# - Check if SUT crashed, reset if necessary
# - Save kdump data, unless NO_KDUMP is set
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
use power_action_utils 'power_action';
use filesystem_utils qw(format_partition);

# xfstests variables
# - XFSTESTS_RANGES: Set sub tests ranges. e.g. XFSTESTS_RANGES=xfs/100-199 or XFSTESTS_RANGES=generic/010,generic/019,generic/038
# - XFSTESTS_BLACKLIST: Set sub tests not run in XFSTESTS_RANGES. e.g. XFSTESTS_BLACKLIST=generic/010,generic/019,generic/038
# - XFSTESTS_GROUPLIST: Include/Exclude tests in group(a classification by upstream). e.g. XFSTESTS_GROUPLIST='auto,!dangerous_online_repair'
# - XFSTESTS_SUBTEST_MAXTIME: Debug use. To set the max time to wait for sub test to finish. Meet this time frame will trigger reboot, and continue next tests.
# - XFSTESTS: TEST_DEV type, and test in this folder and generic/ folder will be triggered. XFSTESTS=(xfs|btrfs|ext4)
# - XFSTESTS_TIMEOUT: test timeout, default is 2000
my $TEST_RANGES  = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/opt/wrapper.sh';
my %BLACKLIST    = map { $_ => 1 } split(/,/, get_var('XFSTESTS_BLACKLIST'));
my @GROUPLIST    = split(/,/, get_var('XFSTESTS_GROUPLIST'));
my $STATUS_LOG   = '/opt/status.log';
my $INST_DIR     = '/opt/xfstests';
my $LOG_DIR      = '/opt/log';
my $KDUMP_DIR    = '/opt/kdump';
my $FSTYPE       = get_required_var('XFSTESTS');
my $TIMEOUT      = get_var('XFSTESTS_TIMEOUT', 2000);
my ($status, $test_start, $test_duration);

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
    my ($test, $status, $time) = @_;
    my $name = test_name($test);
    die "Required variable test: $test or status: $status is missing" unless ($name and $status);
    type_string("\n");
    assert_script_run("echo '$name ... ... $status (${time}s)' >> $STATUS_LOG");
}

# Return all the tests of a specific xfstests category
# category - xfstests category(e.g. generic)
# dir      - xfstests installation dir(e.g. /opt/xfstests)
sub tests_from_category {
    my ($category, $dir) = @_;
    my $cmd    = "find '$dir/tests/$category' -regex '.*/[0-9]+'";
    my $output = script_output($cmd, 60);
    my @tests  = split(/\n/, $output);
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
    my %tests_list  = ();
    my $test_folder = $TEST_RANGES =~ /generic/ ? "generic" : $FSTYPE;
    foreach my $group_name (@GROUPLIST) {
        next if ($group_name !~ /^\!/);
        $group_name = substr($group_name, 1);
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
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
        my $cmd = "awk '/$group_name/' $INST_DIR/tests/$test_folder/group | awk '{printf \"$test_folder/\"}{printf \$1}{printf \",\"}' > tmp.group";
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
        my ($min,      $max)     = (0, 99999);
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

# Save kdump data for further uploading
# test   - corresponding test(e.g. xfs/009)
# dir    - Save kdump data to this dir
# vmcore - include vmcore file
# kernel - include kernel
sub save_kdump {
    my ($test, $dir, %args) = @_;
    $args{vmcore} ||= 0;
    $args{kernel} ||= 0;
    $args{debug}  ||= 0;
    my $name = test_name($test);
    my $ret  = script_run("mv /var/crash/* $dir/$name");
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

# Set mkfs parameter for different scenario
sub mkfs_setting {
    # In case to test xfs reflink feature, test name contain "reflink"
    if (index(get_required_var('TEST'), 'reflink') != -1) {
        my $cmd = <<END_CMD;
mkfs.xfs -f -m reflink=1 \$TEST_DEV
export XFS_MKFS_OPTIONS="-m reflink=1"
END_CMD
        script_run($cmd);
    }
}

sub reload_loop_device {
    assert_script_run("losetup -fP $INST_DIR/test_dev");
    my $scratch_amount = script_output("ls $INST_DIR/scratch_dev* | wc -l");
    my $scratch_num    = 1;
    while ($scratch_amount >= $scratch_num) {
        assert_script_run("losetup -fP $INST_DIR/scratch_dev$scratch_num", 300);
        $scratch_num += 1;
    }
    script_run('losetup -a');
    format_partition("$INST_DIR/test_dev", $FSTYPE);
}

# Umount TEST_DEV and SCRATCH_DEV
sub umount_xfstests_dev {
    script_run('umount ' . get_var('XFSTESTS_TEST_DEV') . ' &> /dev/null')    if get_var('XFSTESTS_TEST_DEV');
    script_run('umount ' . get_var('XFSTESTS_SCRATCH_DEV') . ' &> /dev/null') if get_var('XFSTESTS_SCRATCH_DEV');
    if (get_var('XFSTESTS_SCRATCH_DEV_POOL')) {
        script_run("umount $_ &> /dev/null") foreach (split ' ', get_var('XFSTESTS_SCRATCH_DEV_POOL'));
    }
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
    my $ret = script_output("egrep -m 1 \"filesystem on .+ is inconsistent\" $LOG_DIR/$category/$num");
    if ($ret =~ /filesystem on (.+) is inconsistent/) { $cmd = "umount $1;btrfs-image $1 $LOG_DIR/$category/$num.img"; }
    script_run($cmd);
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

# Run a single test and write log to file
# test - test to run(e.g. xfs/001)
sub test_run {
    my ($self,     $test) = @_;
    my ($category, $num)  = split(/\//, $test);
    eval {
        $test_start = time();
        assert_script_run("timeout " . ($TIMEOUT - 5) . " $TEST_WRAPPER '$test' -k | tee $LOG_DIR/$category/$num", $TIMEOUT);
        $test_duration = time() - $test_start;
    };
    if ($@) {
        $status        = 'FAILED';
        $test_duration = time() - $test_start;
        sleep(2);
        copy_log($category, $num, 'out.bad');
        copy_log($category, $num, 'full');
        copy_log($category, $num, 'dmesg');
        copy_fsxops($category, $num);
        collect_fs_status($category, $num);
        if (get_var('BTRFS_DUMP', 0) && (check_var 'XFSTESTS', 'btrfs')) { dump_btrfs_img($category, $num); }

        #return to VNC due to grub2 and linux-login needle
        select_console('root-console');
        power_action('reboot', keepconsole => 1);
        reconnect_mgmt_console if is_pvm;
        $self->wait_boot(bootloader_time => 500);

        $self->select_serial_terminal;
        # Save kdump data to KDUMP_DIR if not set "NO_KDUMP"
        unless (get_var('NO_KDUMP')) {
            unless (save_kdump($test, $KDUMP_DIR, vmcore => 1, kernel => 1, debug => 1)) {
                # If no kdump data found, write warning to log
                my $msg = "Warning: $test crashed SUT but has no kdump data";
                script_run("echo '$msg' >> $LOG_DIR/$category/$num");
            }
        }

        # Add test status to STATUS_LOG file
        log_add($test, $status, $test_duration);

        # Reload loop device after a reboot
        if (get_var('XFSTESTS_LOOP_DEVICE')) {
            reload_loop_device;
        }
    }
    else {
        $status = 'PASSED';
        # Add test status to STATUS_LOG file
        log_add($test, $status, $test_duration);
        umount_xfstests_dev;
    }
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

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

    mkfs_setting;
    foreach my $test (@tests) {
        # Skip tests inside blacklist
        if (exists($BLACKLIST{$test})) {
            next;
        }

        # Run test and wait for it to finish
        my ($category, $num) = split(/\//, $test);
        test_run($self, $test);
    }

    assert_script_run("tar zcvf /tmp/opt_logs.tar.gz --absolute-names /opt/log/");
}

sub post_fail_hook {
    my ($self) = shift;
    # Collect executed test logs
    script_run 'tar zcvf /tmp/opt_logs.tar.gz --absolute-names /opt/log/';
    upload_logs '/tmp/opt_logs.tar.gz';
}

1;
