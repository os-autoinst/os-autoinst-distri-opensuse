# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: libvirt-daemon xen-tools nmap
# Summary: Export XML from virsh and create new guests in xl stack
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    record_info "XML", "Export the XML from virsh and convert it into Xen config file";
    assert_script_run "virsh dumpxml $_ > $_.xml" foreach (keys %virt_autotest::common::guests);
    # SLES version is greater than 15-SP5, remove network from dumpxml file more information bsc#1222584
    if (is_sle('>15-SP5')) {
        assert_script_run "sed -i '/<interface type/,/<\\/interface>/d' $_.xml" foreach (keys %virt_autotest::common::guests);
    }
    assert_script_run "virsh domxml-to-native xen-xl $_.xml > $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    # Add network configuration to xen-xl cfg files
    if (is_sle('>15-SP5')) {
        record_info "Name", "Add network to xen-xl cfg";
        assert_script_run "echo 'vif = [ \"mac=$_->{macaddress},bridge=virbr0,script=vif-bridge\" ]' >> $_->{name}.xml.cfg" foreach (values %virt_autotest::common::guests);
    }
    record_info "Name", "Change the name by adding suffix _xl";
    assert_script_run "sed -rie 's/(name = \\W)/\\1xl-/gi' $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat $_.xml.cfg | grep name" foreach (keys %virt_autotest::common::guests);

    record_info "UUID", "Change the UUID by using f00 as three first characters";
    assert_script_run "sed -rie 's/(uuid = \\W)(...)/\\1f00/gi' $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat $_.xml.cfg | grep uuid" foreach (keys %virt_autotest::common::guests);

    record_info "Start", "Start the new VM";
    assert_script_run "xl create $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "xl list xl-$_" foreach (keys %virt_autotest::common::guests);

    record_info "SSH", "Test that the new VM listens on SSH";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 30, retry => 12 foreach (keys %virt_autotest::common::guests);

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

