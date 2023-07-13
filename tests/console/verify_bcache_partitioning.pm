# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bcache-tools
# Summary: Validate bcache in writethrough
# Usually the caching device is a fast device (ssd). In this scenario a rotational device is used.
# The whole second disk is used as a caching device with /home mounted as a backing partition.
# This doesnt give any significant performance advantages but it is better to test bcache with this setup
# than use bcache without caching(which yast provides a option if we want to do so)
# Scenarios covered:
# - Verify that certain values are set correctly in a bcache setup after installation.
# - Write operation in a backing device can be performed and validate that cache is working watching the cache hits.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_true';

sub run {
    my $test_data = get_test_suite_data();
    my $cachingdev = $test_data->{profile}->{partitioning}->{drive}->[1]->{device};
    select_console 'root-console';

    # assert the registered backing dev
    assert_script_run "cat /sys/block/bcache0/bcache/backing_dev_name | grep $test_data->{backingdev}";
    # assert bcache is running
    assert_script_run "cat /sys/block/bcache0/bcache/running | grep 1";
    # assert bcache is setup and is not cached dirty data
    assert_script_run "cat /sys/block/bcache0/bcache/state | grep clean";

    record_info("bcache info", "Show info of bcache $cachingdev");
    assert_script_run "bcache-super-show $cachingdev";
    assert_script_run "cat /proc/partitions";

    record_info("write operation");
    my $hit_i = script_output "cat /sys/block/bcache0/bcache/stats_total/cache_hits";
    record_info "cache_hits before", "$hit_i";
    my $path_in_backingdev = "/home/bernhard/one/two/three";
    assert_script_run "mkdir -p $path_in_backingdev";
    assert_script_run "touch ${path_in_backingdev}/data";
    assert_script_run "dd bs=1024 count=1000000 < /dev/random > ${path_in_backingdev}/data";

    my $hits_f = script_output "cat /sys/block/bcache0/bcache/stats_total/cache_hits";
    assert_true($hit_i < $hits_f, "$hits_f should be bigger than $hit_i");
}

1;
