# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: make the guests(specified by test suite settings) ready(virsh define).
# Maintainer: Julie CAO <jcao@suse.com>
package restore_guests;

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use virt_autotest::utils qw(remove_vm restore_downloaded_guests);
use virt_utils qw(get_guest_list);

sub run {
    my $guest_list = get_guest_list();
    my $downloaded_xml_dir = "/tmp/download_vm_xml";

    #clean up env
    my $listed_guests = script_output "virsh list --all --name | sed '/Domain-0/d'";
    foreach my $guest (split "\n", $listed_guests) {
        remove_vm($guest);
    }

    foreach my $guest (split "\n", $guest_list) {
        if (script_run("ls $downloaded_xml_dir/$guest.xml") == 0) {
            restore_downloaded_guests($guest, $downloaded_xml_dir);
        }
    }
}

sub post_fail_hook {
    my $self = shift;

    diag("Module restore_guests post fail hook starts.");
    my $downloaded_xml_dir = "/tmp/download_vm_xml";
    upload_virt_logs($downloaded_xml_dir, "downloaded_guest_xml");
    $self->SUPER::post_fail_hook;
}


sub test_flags {
    return {fatal => 1};
}

1;
