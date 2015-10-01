use base "y2logsstep";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen 'disk-activation', 15;
    send_key 'alt-d';   # configure DASD disk
    assert_screen 'dasd-disk-management';
    send_key 'alt-m';   # minimum channel ID
    type_string '0.0.0150';
    send_key 'alt-x';   # maximum channel ID
    type_string '0.0.0150';
    send_key 'alt-f';   # filter button
    assert_screen 'dasd-unselected';
    send_key 'alt-s';   # select all
    assert_screen 'dasd-selected';
    send_key 'alt-a';   # perform action button
    assert_screen 'action-list';
    send_key 'a';       # activate

    if (check_screen 'dasd-format-device') {    # format device pop-up
        send_key 'alt-o';   # continue
        while (check_screen 'process-format') { # format progress
            printf "formating ...\n";
            sleep 20;
        }
    }
    ### Commented out below becuase of bsc#937340
    #elsif (!get_var('UPGRADE') && !get_var('ZDUP')) {
    #    send_key 'alt-s';   # select all
    #    assert_screen 'dasd-selected';
    #    send_key 'alt-a';   # perform action button
    #    if (check_screen 'dasd-device-formatted'){
    #        assert_screen 'action-list';
    #        send_key 'f';
    #        send_key 'f';   # Pressing f twice because of bsc#940817
    #        send_key 'ret';
    #        assert_screen 'confirm-format';
    #        send_key 'alt-y';
    #        while (check_screen 'process-format') {
    #            printf "formating ...\n";
    #            sleep 20;
    #       }
    #   }
    #}
    sleep 5;
    assert_screen 'dasd-active';
    send_key 'alt-n';   # next
    sleep 5;
    assert_screen 'disk-activation', 15;
    send_key 'alt-n';   # next
    sleep 5;
}

1;
# vim: set sw=4 et:
