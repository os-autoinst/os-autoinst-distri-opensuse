use base "installstep";
use bmwqemu;

# run all application tests after an extra reboot
# first boot is special - could have used kexec and has second stage configuration
sub is_applicable() {
    return 0 if $envs->{LIVETEST} || $envs->{NICEVIDEO} || $envs->{DUALBOOT};

    # Only because of kde/qt has a rendering error on i586 in qemu (bnc#847880).
    # Also check 700_BNC847880_QT_cirrus.pm
    return 1 if $envs->{DESKTOP} eq "kde";

    #	return 1 if $envs->{DESKTOP} eq "kde" && !$envs->{UPGRADE}; # FIXME
    #	return 1 if $envs->{DESKTOP} eq "gnome" && !$envs->{UPGRADE}; # FIXME
    return $envs->{REBOOTAFTERINSTALL} && !$envs->{UPGRADE};
}

sub run() {
    my $self = shift;
    send_key "ctrl-alt-f3";
    sleep 4;
    qemusend "eject ide1-cd0";
    send_key "ctrl-alt-delete";

    wait_encrypt_prompt;
    assert_screen  "reboot_after_install", 200 ;
}

1;
# vim: set sw=4 et:
