# use base qw(shutdown);
# work around for broken base in perl < 5.20
require 'shutdown.pm';
push @ISA, 'shutdown';
use testapi;

sub trigger_shutdown_gnome_button() {
    my ($self) = @_;

    wait_idle;
    send_key "alt-f1"; # applicationsmenu
    my $selected = check_screen 'shutdown_button', 0;
    if (!$selected) {
        send_key_until_needlematch 'shutdown_button', 'tab'; # press tab till is shutdown button selected
    }
    send_key "ret"; # press shutdown button
}

1;
# vim: set sw=4 et:

