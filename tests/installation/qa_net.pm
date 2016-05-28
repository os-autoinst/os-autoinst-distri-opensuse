# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    my ($self) = @_;

    assert_screen "qa-net-selection", 300;

    #send_key_until_needlematch "qa-net-selection-" . get_var('DISTRI') . "-" . get_var("VERSION"), 'down', 30, 3;
    #Don't use send_key_until_needlematch to pick first menu tier as dist network sources might not be ready when openQA is running tests
    send_key 'esc';
    assert_screen 'qa-net-boot';

    my $arch       = get_var('ARCH');
    my $type_speed = 20;
    my $path       = "/mnt/openqa/repo/" . get_var('REPO_0') . "/boot/$arch/loader";
    my $repo       = get_var('HOST') . "/assets/repo/" . get_var('REPO_0');
    type_string "$path/linux initrd=$path/initrd install=$repo ", $type_speed;

    type_string "vga=791 ",                   $type_speed;
    type_string "Y2DEBUG=1 ",                 $type_speed;
    type_string "video=1024x768-16 ",         $type_speed;
    type_string "console=$serialdev,115200 ", $type_speed;    # to get crash dumps as text
    type_string "console=tty ",               $type_speed;    # to get crash dumps as text
    assert_screen 'qa-net-typed';

    my $e = get_var("EXTRABOOTPARAMS");
    if ($e) {
        type_string "$e ", 4;
        save_screenshot;
    }

    send_key 'ret';

}

1;

# vim: set sw=4 et:
