# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: xca basic tests in FIPS mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#104733

use base 'opensusebasetest';
use testapi;
use utils 'zypper_call';
use x11utils qw(close_gui_terminal);

sub run {
    select_console 'root-console';
    zypper_call('in xca');
    select_console('x11');
    x11_start_program('xterm');

    # Start the xca in gui mode
    script_run('xca', 0);
    assert_screen('xca_main_page');

    # Create a new database
    wait_screen_change { send_key 'ctrl-n' };
    save_screenshot;

    # Enter database dir
    wait_screen_change { type_string 'fips_xca' };
    send_key 'ret';
    wait_still_screen 2;

    # Enter the password, that will be used to encrypt the private keys
    type_string("$testapi::password");
    send_key 'tab';
    type_string("$testapi::password");
    wait_still_screen 2;
    save_screenshot;
    send_key 'alt-o';
    wait_still_screen 2;
    save_screenshot;

    # Create new certificate
    send_key 'alt-n';
    wait_still_screen 2;
    send_key 'alt-o';
    wait_still_screen 2;
    save_screenshot;
    send_key 'tab';
    wait_screen_change { send_key 'ret' };
    assert_and_click('xca_create_internal_name');
    # internal name for the certificate
    wait_screen_change { type_string 'susetest' };
    # countryName
    send_key 'tab';
    wait_screen_change { type_string 'DE' };

    # Generate a new key
    send_key 'alt-g';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
    wait_still_screen 2;
    send_key 'alt-o';
    wait_still_screen 2;

    # The certificate contains no extensions, you may apply the
    # extensions of one of the templates to define the purpose
    # of the certificate
    send_key 'alt-o';
    assert_and_click('xca_continue_rollout');
    wait_still_screen 2;
    if (check_screen('xca_fips_error_digital', 10)) {
        record_soft_failure('bsc#1198370: error:060800C8:digital envelope routines:EVP_DigestInit_ex:disabled for FIPS');
    }
    assert_screen('certificate_create_complete');

    # Clean up
    send_key 'alt-o';
    close_gui_terminal;
}

1;
