#Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Import and test Windows guest
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub remove_guest {
    my $guest = shift;

    if (script_run("virsh list --all | grep '$guest'", 90) == 0) {
        assert_script_run "virsh destroy $guest";
        assert_script_run "virsh undefine $guest";
    }
}

sub run {
    my $self     = shift;
    my $username = 'Administrator';

    remove_guest $_ foreach (keys %virt_autotest::common::imports);

    import_guest $_,       'virt-install'                            foreach (values %virt_autotest::common::imports);
    add_guest_to_hosts $_, $virt_autotest::common::imports{$_}->{ip} foreach (keys %virt_autotest::common::imports);

    # Check if SSH is open because of that means that the guest is installed
    ensure_online $_, skip_ssh => 1 foreach (keys %virt_autotest::common::imports);

    ssh_copy_id $_, username => $username, authorized_keys => 'C:\ProgramData\ssh\administrators_authorized_keys', scp => 1 foreach (keys %virt_autotest::common::imports);

    # Print system info, upload it and check the OS version
    assert_script_run "ssh $username\@$_ 'systeminfo' | tee /tmp/$_-systeminfo.txt"                            foreach (keys %virt_autotest::common::imports);
    upload_logs "/tmp/$_-systeminfo.txt"                                                                       foreach (keys %virt_autotest::common::imports);
    assert_script_run "ssh $username\@$_ 'systeminfo' | grep '$virt_autotest::common::imports{$_}->{version}'" foreach (keys %virt_autotest::common::imports);

    remove_guest $_ foreach (keys %virt_autotest::common::imports);
}

1;
