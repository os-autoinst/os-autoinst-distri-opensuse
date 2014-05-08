# auther xjin
use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide(1);

    # to clear all of previous settings and then open the app
    x11_start_program("rm -rf .mozilla");
    x11_start_program("pkill -9 firefox");
    x11_start_program("firefox");
    sleep 10;

    # first confirm www.baidu.com has not been bookmarked yet.
    send_key "ctrl-shift-o";
    sleep 1;
    send_key "tab";
    sleep 1;
    send_key "tab";
    sleep 1;
    sendautotype "www.baidu.com";
    send_key "ret";
    sleep 3;

    checkneedle( "bookmark-not-yet", 2 );
    send_key "alt-f4";

    # bookmark the page
    send_key "ctrl-l";
    sendautotype "www.baidu.com";
    sleep 1;
    send_key "ret";
    sleep 6;
    checkneedle( "bookmark-baidu-main", 3 );

    send_key "ctrl-d";
    sleep 2;
    checkneedle( "bookmarking", 3 );
    send_key "ret";
    sleep 2;

    # check all bookmarked page and open baidu mainpage in a new tab
    send_key "ctrl-t";
    sleep 1;
    send_key "ctrl-shift-o";
    sleep 1;

## check toolbar menu and unsorted section displayed; and baidu mainpage in menu section
    checkneedle( "bookmark-all-bookmark-menu", 3 );
    send_key "down";
    sleep 1;
    send_key "ret";
    checkneedle( "bookmark-baidu-under-bookmark-menu", 3 );

## open baidu page
    send_key "tab";
    send_key "tab";
    send_key "tab";
    sendautotype "www.baidu.com";
    send_key "ret";
    send_key "ret";
    send_key "tab";
    send_key "tab";
    send_key "ret";
    sleep 2;

    checkneedle( "bookmark-baidu-main", 2 );

    # close the bookmark lib page and then close firefox
    send_key "alt-tab";
    sleep 2;
    send_key "alt-f4";
    sleep 5;
    checkneedle( "bookmark-menu-closed", 3 );

## close firefox
    send_key "alt-f4";
    sleep 1;
    send_key "ret";
}

1;
# vim: set sw=4 et:
