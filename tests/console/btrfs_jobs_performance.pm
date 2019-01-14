# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create writes in different btrfs snapshots and monitor btrfs maintenance job performance.
# Maintainer: 

use base 'btrfs_test';
use strict;
use testapi;
use utils 'clear_console';

my $dest = "/mnt/sv";

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run("zypper --non-interactive install stress-ng");

    my $start_perf = script_output("stress-ng --class io --sequential 0 --hdd 1 | awk '{print $5}'");

    # Set up
    assert_script_run "mkdir $dest";
    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');
    assert_script_run "mkfs.btrfs -f $disk && mount $disk $dest && cd $dest";
    assert_script_run "btrfs quota enable .";
    
    # Create subvolumes, qgroups, assigns and limits
    #      2/1
    #     /   \
    #   1/1   1/2
    #  /   \ / | \
    # a     b  c  d(k)
    assert_script_run "for c in {a..d}; do btrfs subvolume create \$c; done";
    assert_script_run "for c in 1/1 1/2 2/1; do btrfs qgroup create \$c .; done";

    assert_script_run "for c in a b; do btrfs qgroup assign --no-rescan \$c 1/1 .; done";
    assert_script_run "for c in b c d; do btrfs qgroup assign --no-rescan \$c 1/2 .; done";
    assert_script_run "for c in 1/1 1/2; do btrfs qgroup assign \$c 2/1 .; done";

    # Set limits
    assert_script_run "btrfs qgroup limit 20g a .";
    assert_script_run "btrfs qgroup limit 20g 1/1 .";
    assert_script_run "btrfs qgroup limit 20g 2/1 .";

    # Fill with data
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=100 of=a/file\$c; done";
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=100 of=b/file\$c; done";
    assert_script_run "for c in {1..20}; do dd if=/dev/zero bs=1M count=100 of=c/file\$c; done";
    assert_script_run "for c in {1..15}; do dd if=/dev/zero bs=1M count=100 of=d/file\$c; done";

    # Create snapshots
    assert_script_run "btrfs subvolume snapshot a k";
    assert_script_run "btrfs subvolume snapshot b l";
    assert_script_run "btrfs subvolume snapshot c m";
    assert_script_run "btrfs subvolume snapshot d n";

    assert_script_run "for c in k l; do btrfs qgroup assign --no-rescan \$c 1/1 .; done";
    assert_script_run "for c in l m; do btrfs qgroup assign --no-rescan \$c 1/2 .; done";
    assert_script_run "btrfs qgroup assign --rescan n 1/2 .";

    # Remove data in original subvolume
    assert_script_run "rm {a,b,c,d}/file*";

    # Re-fill original subvolumes
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=100 of=a/file\$c; done";
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=100 of=b/file\$c; done";
    assert_script_run "for c in {1..20}; do dd if=/dev/zero bs=1M count=100 of=c/file\$c; done";
    assert_script_run "for c in {1..15}; do dd if=/dev/zero bs=1M count=100 of=d/file\$c; done";

    # Remove original data in original subvolume
    assert_script_run "rm {a,b,c,d}/file*";

    assert_script_run "for c in {a..d}; do btrfs subvolume delete \$c; done";

    # start btrfs maintanance scripts via systemctl
    my $systemd_tasks_cmd = 'echo "Triggering systemd timed service $i" && systemctl start $i.service && systemctl mask $i.{service,timer}';
    assert_script_run('for i in btrfs{-balance,-scrub,-trim}; do ' . $systemd_tasks_cmd . '; done');

    # Generate load

    my $end_perf = script_output("stress-ng --class io --sequential 0 --hdd 1 | awk '{print $5}'");

    return 0 unless (($start_perf - $end_perf) < 100);
    # This should be improved, just take 100 looks for now
    # for (1..100) {
    # 	my $io_status = script_output("sed -n 's/^.*da / /p' /proc/diskstats | cut -d' ' -f10");
    # 	if ($io_status > 100)
    # 	{
    # 	    # Or just fail hard here
    # 	    record_soft_failure 'bsc#1063638';
    # 	}
    # }

    assert_script_run "cd; umount $dest";
    assert_script_run "btrfsck $disk";
    $self->cleanup_partition_table;
}
1;
		      
