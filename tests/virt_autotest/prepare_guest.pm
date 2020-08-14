# Summary: make the guests(specified by test suite settings) ready(virsh define).
# Maintainer: Julie CAO <jcao@suse.com>
package prepare_guest;

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;
use version_utils 'is_sle';
use virt_utils qw(get_guest_list remove_vm);

sub run {
    # figure out the guest list to be prepared
    my $tested_guests = get_guest_list();

    #clean up other guests and define needed guests, or the step is done by restore_guests? no, some step not restore guests.
    my $listed_guests = script_output("virsh list --all | sed -n '/^-/,\$p' | sed '1d;/Domain-0/d' | awk '{print \$2;}'", 30);
    foreach (split "\n", $listed_guests) {
        $_ =~ /^((\w+-){1,6}\w+)/;
        my $domain = $&;
        remove_vm($_) unless (grep /$domain/, $tested_guests);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
