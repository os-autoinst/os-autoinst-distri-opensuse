# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate read/write operations over mountpoints specified
# in test data.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use File::Spec::Functions 'catfile';

sub run {
    select_console('root-console');
    my $disks = get_test_suite_data()->{disks};

    my ($mountpoint, $path);
    foreach my $disk (@{$disks}) {
        foreach my $part (@{$disk->{partitions}}) {
            if ($part->{mounting_options} && $part->{mounting_options}{should_mount}) {
                $mountpoint = $part->{mounting_options}{mount_point};
                # exclude SWAP and boot partitions
                next if $mountpoint =~ /\/boot|\[SWAP\]|SWAP/;
                $path = catfile($mountpoint, 'emptyfile');
                assert_script_run("echo Hello > $path",
                    fail_message => "Failure while writing to $mountpoint");
                assert_script_run("grep Hello $path",
                    fail_message => "Failure while reading from $mountpoint");
            }
        }
    }
}

1;
