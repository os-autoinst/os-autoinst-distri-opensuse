use base "basetest";
use strict;
use testapi;

sub run {
    assert_screen 'encrypted_volume_activation_prompt';
    if (get_var('ENCRYPT_CANCEL_EXISTING')) {
	send_key 'alt-c', 5;
	if (check_screen('encrypted_volume_activation_prompt')) {
	    record_soft_failure 'bsc#989770';
	    send_key 'alt-c';
	}
    } elsif (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
	send_key 'alt-p';
	assert_screen 'encrypted_volume_password_prompt', 10;
	type_password;
	send_key 'ret';
    }
}

sub test_flags {
    return {
	fatal => 1
    };
}

1;
