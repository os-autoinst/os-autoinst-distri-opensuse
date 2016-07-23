# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils qw/ensure_shim_import/;

sub run {
    my $self = shift;

    ensure_shim_import;
    $self->select_bootmenu_option('inst-onmediacheck', 1);

    # the timeout is insane - but SLE11 DVDs take almost forever
    assert_screen [qw/mediacheck-ok mediacheck-checksum-wrong/], 3600;
    send_key "ret";
    if (match_has_tag('mediacheck-checksum-wrong')) {
        die "Checksum reported as wrong";
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
