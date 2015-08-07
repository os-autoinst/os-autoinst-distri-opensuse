use base "opensusebasetest";
use strict;
use testapi;
use ttylogin;

sub run() {
    my $self = shift;
    assert_screen 'linux-login';

    send_key 'ctrl-alt-f4';
    assert_screen 'tty4-selected';
    assert_screen 'text-login';
    type_string "root\n";
    assert_screen 'password-prompt', 10;
    type_string "linux\n";
    assert_screen 'text-logged-in';
    
    assert_screen 'jeos-keylayout'; # Language picker
    
    #TODO - add support for INSTLANG. The next two lines are a 'dead end' because the menu is longer than 20 characters and send_key_until_needlematch will never get to the default of US
    #my $chosenlang = get_var("INSTLANG") || 'en_US'; # If INSTLANG not set, use en_US
    #send_key_until_needlematch "jeos-lang-$chosenlang", 'down'; 
    
    send_key_until_needlematch 'jeos-lang-en_US', 'u'; # Press u until it gets to the US menu option
    send_key 'spc'; # Select option
    assert_screen 'jeos-langselected'; # Make sure its selected
    send_key 'ret'; # Press enter, go to License
    
    assert_screen 'jeos-license'; # License time
    send_key_until_needlematch 'jeos-license-end', 'pgdn'; # Might as well scroll to the bottom, somewhat redundant
    send_key 'q';
    assert_screen 'jeos-doyouaccept';
    send_key 'y';
    send_key 'ret';
    assert_screen 'jeos-firstrun-finished'; # Check the config made

    type_string "useradd -m $username\n"; # Make bernhard his account    
    type_string "echo 'root:$password' | chpasswd\n"; # need to fix roots password
    type_string "echo '$username:$password' | chpasswd\n"; # need to fix bernhards password
    
    script_run 'exit'; # Get back to tty so it can work
    
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
