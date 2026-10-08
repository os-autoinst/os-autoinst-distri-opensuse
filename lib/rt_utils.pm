package rt_utils;
use base Exporter;
use testapi;
use strict;
use warnings;
use Exporter;

our @EXPORT = qw(
  select_kernel
);

sub select_kernel {
    my $kernel = shift;

    assert_screen ['grub2', "grub2-$kernel-selected"], 100;
    if (match_has_tag "grub2-$kernel-selected") {    # if requested kernel is selected continue
        send_key 'ret';
    }
    else {    # else go to that kernel thru grub2 advanced options
        send_key_until_needlematch 'grub2-advanced-options', 'down';
        send_key 'ret';
        send_key_until_needlematch "grub2-$kernel-selected", 'down';
        send_key 'ret';
    }
    if (get_var('NOAUTOLOGIN')) {
        assert_screen 'displaymanager', 200;
        mouse_hide(1);
        send_key 'ret';
        assert_screen 'displaymanager-password-prompt', no_wait => 1;
        type_password;
        send_key 'ret';
    }
}

1;
