# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#package qa_run;
use strict;
use warnings;
use File::Basename;
use testapi;
use lib "/var/lib/openqa/share/tests/sle-12-SP2/tests/virt_autotest/common";
use base "reboot_and_wait_up";

sub run() {
	my $self=shift;
	my $timeout=3600;
	set_var("reboot_for_upgrade_step","yes");
	$self->reboot_and_wait_up($timeout);
}

sub test_flags {
    return {important => 1};
}

1;

