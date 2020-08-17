# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple vmware client testing with updated open-vm-tools
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use xen;

sub run {
    my ($self) = @_;

    script_retry "ssh root\@$_ zypper -n in open-vm-tools", delay => 30, retry => 6 foreach (keys %xen::guests);

    assert_script_run "ssh root\@$_ /usr/bin/vmware-checkvm | grep 'good'" foreach (keys %xen::guests);

    assert_script_run "ssh root\@$_ systemctl restart vmtoolsd.service"                               foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ systemctl status vmtoolsd.service | grep 'Started open-vm-tools'" foreach (keys %xen::guests);

    assert_script_run "ssh root\@$_ /usr/bin/vmtoolsd -v | grep 'VMware Tools daemon, version'" foreach (keys %xen::guests);

    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level set vmtoolsd debug"                           foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = debug'" foreach (keys %xen::guests);

    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level set vmtoolsd message"                           foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = message'" foreach (keys %xen::guests);

}

1;
