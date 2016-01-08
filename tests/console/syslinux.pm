# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

# for https://bugzilla.novell.com/show_bug.cgi?id=679459

sub run() {
    my $self = shift;
    script_run("cd /tmp ; wget -q openqa.opensuse.org/opensuse/qatests/qa_syslinux.sh");
    $self->clear_and_verify_console;
    script_sudo("sh -x qa_syslinux.sh");
    assert_screen 'test-syslinux-1', 3;
}

1;
# vim: set sw=4 et:
