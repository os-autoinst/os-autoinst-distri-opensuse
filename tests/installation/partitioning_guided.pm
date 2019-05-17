# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use guided partitioning setup to delete an existing windows partition.
# Maintainer: Christopher Hofmann <cwh@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub save_logs_and_resume {
    my $self = shift;
    $self->get_to_console;
    $self->save_upload_y2logs();
    select_console 'installation';
}

sub run() {
    die "Module only supports StorageNG" if !get_var("STORAGE_NG");

    # Enter guided setup
    send_key "alt-g";

    assert_screen 'inst-partition-guided';

    assert_and_click 'resize-remove-if-needed';
    assert_and_click 'remove-if-not-needed';
    send_key 'alt-n';

    assert_and_click 'inst-partitioning-scheme';
    send_key 'alt-n';

    assert_screen 'inst-filesystem-options';
    send_key 'alt-n';

    assert_screen 'delete-windows';
}

1;
