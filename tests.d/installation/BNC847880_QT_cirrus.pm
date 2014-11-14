use base "y2logsstep";
use bmwqemu;

# Only because of kde/qt has a rendering error on i586 in qemu (bnc#847880).
# Remove after QT fixed the bug

sub is_applicable() {
    my $self = shift;
    return 0;
    # return y2logsstep_is_applicable && $vars{DESKTOP} eq "kde" && !$vars{DUALBOOT};
}

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    become_root();
    type_string "echo QT_GRAPHICSSYSTEM=native >> /etc/environment\n";
    type_string "exit\n";
    type_string "exit\n";
    save_screenshot();
}

1;
# vim: set sw=4 et:
