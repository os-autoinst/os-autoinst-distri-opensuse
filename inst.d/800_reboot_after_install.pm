use base "installstep";
use bmwqemu;

# run all application tests after an extra reboot
# first boot is special - could have used kexec and has second stage configuration
sub is_applicable() {
    return 0 if $vars{LIVETEST} || $vars{NICEVIDEO} || $vars{DUALBOOT};

    # Only because of kde/qt has a rendering error on i586 in qemu (bnc#847880).
    # Also check 700_BNC847880_QT_cirrus.pm
    return 1 if $vars{DESKTOP} eq "kde";

    #	return 1 if $vars{DESKTOP} eq "kde" && !$vars{UPGRADE}; # FIXME
    #	return 1 if $vars{DESKTOP} eq "gnome" && !$vars{UPGRADE}; # FIXME
    return $vars{REBOOTAFTERINSTALL} && !$vars{UPGRADE};
}

sub run() {
    my $self = shift;
    send_key "ctrl-alt-f3";
    sleep 4;
    send_key "ctrl-alt-delete";

    wait_encrypt_prompt;
    assert_screen  "reboot_after_install", 200;
}

1;
# vim: set sw=4 et:
