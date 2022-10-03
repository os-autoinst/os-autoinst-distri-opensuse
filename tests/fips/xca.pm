# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: xca basic tests in FIPS mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#104733

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call('in xca');
    select_console('x11');
    x11_start_program('xterm');

    # Start the xca in gui mode
    script_run('xca', 0);
    assert_screen('xca_main_page');

    # Create a new database
    send_key 'ctrl-n';
    wait_still_screen 2;
    save_screenshot;

    # Enter database dir
    type_string('fips_xca');
    assert_and_click('xca_database_save');
    wait_still_screen 2;
    save_screenshot;

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
    save_screenshot;
    send_key 'alt-o';
    wait_still_screen 2;
    save_screenshot;
    send_key 'tab';
    send_key 'ret';
    assert_and_click('xca_create_initernal_name');

    # Enter the internal name for the certificate
    type_string('susetest');

    # Generate a new key
    send_key 'alt-g';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
    wait_still_screen 2;
    save_screenshot;
    send_key 'alt-o';
    assert_and_click('ok_to_create_certificate');

    # The certificate contains no extensions, you may apply the
    # extensions of one of the templates to define the purpose
    # of the certificate
    assert_and_click('xca_continue_rollout');
    wait_still_screen 2;
    if (check_screen('xca_fips_error_digital', 10)) {
        record_soft_failure('bsc#1198370: error:060800C8:digital envelope routines:EVP_DigestInit_ex:disabled for FIPS');
    }
    send_key 'alt-o';
    assert_screen('certificate_create_complete');

    # Clean up
    send_key 'alt-o';
    send_key 'alt-f4';
}

1;
