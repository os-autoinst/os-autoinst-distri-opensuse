use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;
    assert_screen "remove-repository", 30;
    send_key $cmd{"next"}, 1;
    if (check_var('DISTRI', 'opensuse')) {
        if (check_screen('network-not-configured', 5)) {
            send_key 'alt-n';
            if (check_screen('ERROR-cannot-download-repositories')) {
                send_key 'alt-o';
                record_soft_failure;
            }
        }
        if (check_screen('list-of-online-repositories', 10)) {
            send_key 'alt-n';
            record_soft_failure;
        }
        # Bug 881107 - there is 2nd license agreement screen in openSUSE upgrade
        # http://bugzilla.opensuse.org/show_bug.cgi?id=881107
        # (remove after the bug is closed)
        if (check_screen('upgrade-li-cense-agreement', 10)) {
            send_key 'alt-n';
            record_soft_failure;
        }
        if (check_screen('installed-product-incompatible', 10)) {
            send_key 'alt-o'; # C&ontinue
            record_soft_failure;
        }

        assert_screen "update-installation-overview", 15;
    }
}

1;
# vim: set sw=4 et:
