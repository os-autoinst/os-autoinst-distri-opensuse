use base "basetest";
use strict;
use bmwqemu;

# show installed GNOME components, allows to look for possibly unwanted
# dependencies

# this function decides if the test shall run
sub is_applicable {
    return ( $envs->{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    script_run('rpm -qa "*nautilus*|*gnome*" | sort | tee /tmp/xfce-gnome-deps');
    script_sudo('mv /tmp/xfce-gnome-deps /var/log');
    script_run("echo 'gnome_deps_ok' >  /dev/ttyS0");
    waitserial( 'gnome_deps_ok', 5 );

}

1;
# vim: set sw=4 et:
