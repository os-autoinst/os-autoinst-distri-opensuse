use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    script_sudo("/sbin/yast2 -i");
    waitstillimage( 36, 90 );
    sendautotype("xdelta\n");
    sleep 3;
    sendkey "spc";    # select for install
    sleep 1;
    $self->check_screen;
    sleep 2;
    sendkeyw "alt-a";    # accept
    waitstillimage( 16, 60 );
    waitforneedle( 'test-yast2_i-shows-summary', 2 );
    sendkeyw "alt-f";    # finish yast2_i
    sleep 1;
    script_run('echo $?');
    $self->check_screen;
    sleep 3;
    sendkey "ctrl-l";                                                            # clear screen to see that second update does not do any more
    script_sudo("rpm -e  xdelta && echo 'xdelta_removed' > /dev/$serialdev");    # extra space to have different result images than for zypper_in test
    waitserial("xdelta_removed") || die "xdelta remove failed";
    script_run("rpm -q xdelta");

    # make sure we go out of here
    waitforneedle( 'test-yast2_i-xdelta-not-installed', 1 );
}

1;
# vim: set sw=4 et:
