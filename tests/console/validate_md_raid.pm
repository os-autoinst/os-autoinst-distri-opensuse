# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test data driven RAID partitioning layout validation,
# Should replace console/validate_raid.pm which uses hardcoded regular
# expressions.
# Module uses same structure as we use to setup raid with extra values:
#   mds:
#     - raid_level: 5
#       name: md0
#       devices:
#         - vda2
#         - vdb2
#         - vdc2
#         - vdd2
#     - raid_level: 0
#       name: md1
#       devices:
#         - vda3
#         - vdb3
#         - vdc3
#         - vdd3
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';

use Config::Tiny;
use Test::Assert ':all';
use Utils::Logging 'save_and_upload_log';

sub run {
    select_console 'root-console';

    my $test_data = get_test_suite_data();
    my ($mdadm_output, $mdadm_cfg);

    foreach my $md (@{$test_data->{mds}}) {
        $mdadm_output = script_output('mdadm --detail --export /dev/' . $md->{name});
        # Settings are in the root section, use '_' key, see Config::Tiny documentation
        $mdadm_cfg = Config::Tiny->read_string($mdadm_output)->{_};

        assert_equals($mdadm_cfg->{MD_LEVEL}, 'raid' . $md->{raid_level}, "Wrong raid level for $md->{name}");
        assert_equals($mdadm_cfg->{MD_DEVICES}, scalar(@{$md->{devices}}), "Wrong number of devices for $md->{name}");

        foreach my $disk (@{$md->{devices}}) {
            assert_equals($mdadm_cfg->{"MD_DEVICE_dev_${disk}_DEV"}, "/dev/$disk", "$disk is not used as a raid device of $md->{name}");
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    save_and_upload_log('mdadm --detail', 'mdadm_output.txt');
    upload_logs('/proc/mdstat', failok => 1);
}

1;
