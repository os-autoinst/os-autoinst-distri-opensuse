# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: libvirt-daemon xen-tools nmap
# Summary: Export XML from virsh and create new guests in xl stack
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my @guests = @{get_var_array("TEST_GUESTS")};
    record_info "XML", "Export the XML from virsh and convert it into Xen config file";
    assert_script_run "virsh dumpxml $_ > $_.xml" foreach (@guests);
    assert_script_run "virsh domxml-to-native xen-xl $_.xml > $_.xml.cfg" foreach (@guests);

    record_info "Name", "Change the name by adding suffix _xl";
    assert_script_run "sed -rie 's/(name = \\W)/\\1xl-/gi' $_.xml.cfg" foreach (@guests);
    assert_script_run "cat $_.xml.cfg | grep name" foreach (@guests);

    record_info "UUID", "Change the UUID by using f00 as three first characters";
    assert_script_run "sed -rie 's/(uuid = \\W)(...)/\\1f00/gi' $_.xml.cfg" foreach (@guests);
    assert_script_run "cat $_.xml.cfg | grep uuid" foreach (@guests);

    record_info "Start", "Start the new VM";
    assert_script_run "xl create $_.xml.cfg" foreach (@guests);
    assert_script_run "xl list xl-$_" foreach (@guests);

    record_info "SSH", "Test that the new VM listens on SSH";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 30, retry => 12 foreach (@guests);

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

