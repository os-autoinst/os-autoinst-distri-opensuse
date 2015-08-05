use base "consoletest";
use strict;
use testapi;

# Testing: Cleanup and consistent naming for snapshots made during installation
# https://bugzilla.suse.com/show_bug.cgi?id=935923
# Checking if cleanup strategy is set to "number"
# and user data is set to "important=yes"

sub run() {
    my $self = shift;

    become_root;
    script_run("snapper ls | grep 'after installation' | tee /dev/$serialdev");

    wait_serial('single\s*(\|[^|]*){4}\s*\|\s*number\s*\|\s*after installation\s*\|\s*important=yes', 10) || die "snapper snapshot test failed";

    script_run("exit");
    send_key "ctrl-l";
}

1;
# vim: set sw=4 et:
