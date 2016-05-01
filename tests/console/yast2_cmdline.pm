# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "console_yasttest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    select_console 'root-console';

    # Install test requirement
    assert_script_run 'zypper -n in rpm-build';

    # Enable source repo
    assert_script_run 'zypper mr -e repo-source';

    # Run YaST CLI tests
    $self->run_yast_cli_test('yast2-network');
    $self->run_yast_cli_test('yast2-dns-server');
}

1;
# vim: set sw=4 et:
