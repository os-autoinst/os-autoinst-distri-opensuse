# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This feature allows USB devices to be passthrough directly to the guest.
#          The added tests are unit test for this feature.
#          Fate link: https://fate.suse.com/316612
#
# Maintainer: xlai@suse.com
use strict;
use warnings;
use base "virt_autotest_base";
use virt_utils;
use testapi;

sub get_script_run {
    my $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-pvusb-run";
    my $which_usb    = get_var("PVUSB_DEVICE", "");
    if ($which_usb eq "") {
        die "The PVUSB_DEVICE is not properly set in workers.ini.";
    }
    my $qa_repo = get_var("QA_HEAD_REPO", "http://dist.nue.suse.com/ibs/QA:/Head/SLE-12-SP3/");
    handle_sp_in_settings_with_sp0("GUEST");
    my $guest = get_var("GUEST", "sles-12-sp3-64-fv-def-net");
    $pre_test_cmd .= " -w \"" . $which_usb . "\"" . " -r $qa_repo -g $guest";

    return $pre_test_cmd;
}

sub run {
    my $self = shift;
    $self->run_test(5000, "Congratulations! All test is successful!", "no", "yes", "/var/log/qa/", "pvusb-test-logs");
}

1;

