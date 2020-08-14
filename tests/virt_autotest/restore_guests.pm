# Summary: make the guests(specified by test suite settings) ready(virsh define).
# Maintainer: Julie CAO <jcao@suse.com>
package restore_guests;

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use virt_utils qw(get_guest_list remove_vm restore_downloaded_guests);

sub run {
    my $guest_list         = get_guest_list();
    my $downloaded_xml_dir = "/tmp/download_vm_xml";

    #clean up env
    my $listed_guests = script_output "virsh list --all | sed -n '/^-/,\$p' | sed '1d;/Domain-0/d' | awk '{print \$2;}'";
    foreach my $guest (split "\n", $listed_guests) {
        remove_vm($guest);
    }

    foreach my $guest (split "\n", $guest_list) {
        restore_downloaded_guests($guest, $downloaded_xml_dir);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
