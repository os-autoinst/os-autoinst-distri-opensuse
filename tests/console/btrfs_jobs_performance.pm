# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
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
use List::Util qw(max);

my $btrfs_fs_usage = 'btrfs filesystem usage / --raw';

sub get_space {
    my $script = @_;
    my $script_output = script_output($script);
    # Problem is that sometimes we get kernel messages or other output when execute the script
    # So we assume that biggest number returned is size we are looking for
    if ($script_output =~ /^(\d+)$/) {
	return $script_output;
    }
    record_soft_failure('bsc#1011815');
    my @numbers = $script_output =~ /^(\d+)/g;

    return max(@numbers);
}

sub run {
    my ($number, $scratchfile_mb, $safety_margin_mb, $initially_free);

    $scratchfile_mb = 1024;
    $safety_margin_mb = 300 + $scratchfile_mb;
    $initially_free = get_space("$btrfs_fs_usage | awk -F ' ' '/Free .estimated.:.*min:/{print\$3}'");    # bytes
    # Copied from snapper_cleanup to calculate number of write operations
    $number = int(($initially_free / ( $scratchfile_mb * $scratchfile_mb) - $safety_margin_mb ) / $scratchfile_mb) * 2;

    for (1..$number) {
	assert_script_run("dd if=/dev/zero of=data.$_ bs=1M count=$scratchfile_mb");
    }
    # Create btrfs snapshot of directory
    # Delete files in directory (-> they are now only available in snapshot)
    # repeat (from line 44) a few times in different directories

    # start btrfs maintanance scripts

    until $END {# find a way to determine the test is over 
	# watch /proc/diskstats for numbers higher than (this needs more investigation) 100
	my $io_status = script_output("sed -n 's/^.*da / /p' /proc/diskstats | cut -d' ' -f10");
	if ($io_status > 100)
	{
	    # fail here
	}
    }


}

		      
