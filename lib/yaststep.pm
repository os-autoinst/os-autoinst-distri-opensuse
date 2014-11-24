# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package yaststep;
use base "consolestep";

use testapi;

sub post_fail_hook() {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 1;

    save_screenshot;

    my $fn = sprintf '/tmp/y2logs-%s.tar.bz2', ref $self;
    type_string "save_y2logs $fn\n";
    upload_logs $fn;
    save_screenshot;
}

1;
# vim: set sw=4 et:
