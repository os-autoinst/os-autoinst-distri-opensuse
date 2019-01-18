package linuxrc;
use base "opensusebasetest";
use testapi;
use strict;
use warnings;

#
# Shared functionality for handling Linuxrc
#

# Waits for the Linuxrc (media) boot menu and tries to choose
# booting from CD/DVD media. Call this right away after VM starts.
sub wait_for_bootmenu {
    my $self = shift;

    # Load the BIOS media selection
    assert_screen "boot-menu", 30;
    send_key "f12";
    wait_still_screen 2;

    my $dvd_found = 0;

    # Tries to find CD/DVD entry one by one from the top.
    for my $try (1 .. 10) {
        my $tag = "boot-menu-boot-device-" . $try . "-dvd";

        if (check_screen($tag, 0)) {
            diag "DVD found at position " . $try . ", tag: " . $tag;
            $dvd_found = $try;
            type_string $try;
            last;
        }
    }

    unless ($dvd_found) {
        save_screenshot;
        die "Cannot find DVD in boot-menu";
    }

    # Waits for booting into the media boot menu
    assert_screen("inst-bootmenu", 30);
}

# Loads Linuxrc with given parameters. Call wait_for_bootmenu() first to
# get into media boot menu.
#
# @param object
# @param string parameters
# @param boot selection needle, default: inst-oninstallation
sub boot_with_parameters {
    my $self           = shift;
    my $parameters     = shift;
    my $boot_selection = shift || "inst-oninstallation";

    unless (check_screen("inst-bootmenu", 0)) {
        die "Installation media not booted, use wait_for_bootmenu() first";
    }

    send_key_until_needlematch($boot_selection, 'down', 10, 5);

    type_string $parameters;
    save_screenshot;

    send_key "ret";
}

1;
