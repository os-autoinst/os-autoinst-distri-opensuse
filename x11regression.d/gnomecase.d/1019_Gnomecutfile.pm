use base "basetest";
use bmwqemu;
use autotest;

#testcase 4158-1249067 move(cut) a file with nautilus

sub is_applicable {
    return ( $vars{DESKTOP} eq "gnome" );
}

#this part contains the steps to run this test
sub run() {

    #create a temporary /tmp/openqatest dir
    my $self = shift;
    x11_start_program("nautilus");
    send_key "ctrl-l";
    sleep 2;
    type_string "/tmp";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "shift-f10";
    sleep 10;
    send_key "w";
    sleep 2;
    send_key "f";
    sleep 2;
    type_string "openqatest";
    sleep 2;
    send_key "ret";
    send_key "ret";
    sleep 2;

    #create a,b dir
    send_key "shift-f10";
    sleep 5;
    send_key "w";
    sleep 2;
    send_key "f";
    sleep 2;
    type_string "a";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ctrl-shift-i";
    sleep 2;
    send_key "shift-f10";
    sleep 5;
    send_key "w";
    sleep 2;
    send_key "f";
    sleep 2;
    type_string "b";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ret";
    sleep 2;

    #under b dir,create a test file "file1"
    x11_start_program("gnome-terminal");
    script_run("cd /tmp/openqatest/b;/usr/bin/touch file1;/usr/bin/chmod 777 file1");
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    assert_screen 'test-Gnomecutfile-1', 3;
    sleep 2;    #
    send_key "down";
    sleep 2;
    send_key "ctrl-x";
    sleep 2;
    send_key "alt-left";
    sleep 2;
    send_key "left";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ctrl-v";
    sleep 2;
    assert_screen 'test-Gnomecutfile-2', 3;
    sleep 2;    #to make sure file1 was aleady moved to a dir
    send_key "alt-left";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    assert_screen 'test-Gnomecutfile-3', 3;
    sleep 2;    #to make sure there is no file1 in b dir
    send_key "alt-f4";
    sleep 2;

    #clean up
    x11_start_program("gnome-terminal");
    script_run( "/usr/bin/rm -rf /tmp/openqatest", 3 );
    sleep 2;
    send_key "alt-f4";
    sleep 2;

}

1;
# vim: set sw=4 et:
