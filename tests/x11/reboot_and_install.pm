# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add ssh key dialog test
#    https://progress.opensuse.org/issues/11454 https://github.com/yast/skelcd-control-SLES/blob/d2f9a79c0681806bf02eb38c4b7c287b9d9434eb/control/control.SLES.xml#L53-L71
# G-Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;

use testapi;
use utils qw/reboot_gnome/;
use bootloader_setup qw/select_bootmenu_option bootmenu_default_params/;

sub run() {
    reboot_gnome;    # reboot from previously booted hdd to do pre check or change e.g. before upgrade
    select_bootmenu_option;
    bootmenu_default_params;
    # boot
    send_key "ret";
}

sub post_fail_hook {
    my $self = shift;
    $self->export_logs;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
