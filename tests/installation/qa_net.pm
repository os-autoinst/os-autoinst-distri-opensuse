use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

use bmwqemu ();

sub run() {
    my ($self) = @_;

    assert_screen "qa-net-selection", 300;
    $bmwqemu::backend->relogin_vnc();

    #$self->key_round("qa-net-selection-" . get_var('DISTRI') . "-" . get_var("VERSION"), 'down', 30, 3); #Don't use keyround to pick first menu tier as dist network sources might not be ready when openQA is running tests
    send_key 'esc';
    assert_screen 'qa-net-boot', 8;

    my $arch = get_var('ARCH');
    my $type_speed = 20;
    my $path = "/mnt/openqa/repo/" . get_var('REPO_0') . "/boot/$arch/loader/";
    type_string "$path/linux initrd=$path/initrd install=http://" . get_var('SUSEMIRROR') . " ", $type_speed;

    type_string "vga=791 ", $type_speed;
    type_string "Y2DEBUG=1 ", $type_speed;
    type_string "video=1024x768-16 ", $type_speed; 
    type_string "console=$serialdev,115200 ", $type_speed;    # to get crash dumps as text
    type_string "console=tty ", $type_speed;    # to get crash dumps as text
    # for some reason we need to reset the "VNC" connection again to see the bottom - most likely because it has the odd resolution of 752x413
    $bmwqemu::backend->relogin_vnc();
    assert_screen 'qa-net-typed', 5;

    my $e = get_var("EXTRABOOTPARAMS");
    if ($e) {
        type_string "$e ", 4;
        save_screenshot;
    }

    send_key 'ret';

}

1;

# vim: set sw=4 et:
