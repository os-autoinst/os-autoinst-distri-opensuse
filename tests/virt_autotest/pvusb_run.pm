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
use Utils::Architectures;

sub get_script_run {
    my $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-pvusb-run";
    my $which_usb    = get_var("PVUSB_DEVICE", "");
    if ($which_usb eq "") {
        die "The PVUSB_DEVICE is not properly set in workers.ini.";
    }
    handle_sp_in_settings_with_sp0("GUEST");
    my $guest = get_var("GUEST", "sles-12-sp3-64-fv-def-net");
    $pre_test_cmd .= " -w \"" . $which_usb . "\"" . " -g $guest";
    my $vm_xml_dir = "/tmp/download_vm_xml";
    if (get_var("SKIP_GUEST_INSTALL") && is_x86_64) {
        $pre_test_cmd .= " -k $vm_xml_dir";
    }

    return $pre_test_cmd;
}

sub run {
    my $self            = shift;
    my $timeout         = get_var('MAX_TEST_TIME', '5000');
    my $upload_log_name = 'pvusb-test-logs';
    $self->run_test($timeout, "Congratulations! All test is successful!", "no", "yes", "/var/log/qa/", $upload_log_name);
}

1;

