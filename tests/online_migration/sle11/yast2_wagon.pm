use base "consoletest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    type_string "yast2 wagon\n";
    assert_screen "yast2-wagon-welcome", 5;
    send_key "alt-n";

    assert_screen "yast2-wagon-regcheck", 100;
    send_key "alt-n";

    assert_screen "yast2-wagon-updatemethod", 100;
    send_key "alt-n";

    assert_screen "yast2-wagon-ncc", 5;
    send_key "alt-n";
    assert_screen "yast2-wagon-ncc-done", 200;
    send_key "alt-o";

    assert_screen "yast2-wagon-upgrade-overview", 30;

    if (check_screen("yast2-wagon-upgrade-overview-warning", 1)) {
        send_key "alt-c";
        assert_screen "yast2-wagon-upgrade-overview-options", 3;
        send_key "alt-p";
        assert_screen "yast2-wagon-upgrade-dependancy-issue", 5;
        die "Dependency Warning Detected";
    }

    # start upgrading
    send_key "alt-n";
    assert_screen "yast2-wagon-start-upgrade", 5;
    send_key "alt-u";
    assert_screen "yast2-wagon-upgrading", 30;

    # the process of upgrading may take very long time due to connection speed
    my $timeout = 5000;
    assert_screen "yast2-wagon-reboot-system", $timeout;
    send_key "alt-o";    # done upgrading

    # register via ncc again
    assert_screen "yast2-wagon-ncc", 60;
    send_key "alt-n";
    assert_screen "yast2-wagon-ncc-done", 200;
    send_key "alt-o";

    # migration finished
    assert_screen "yast2-wagon-finished", 20;
    send_key "alt-f";
    assert_screen "yast2-wagon-exited", 15;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
