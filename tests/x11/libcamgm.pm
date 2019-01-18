# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test libcamgm via Yast2 CA management module(yast2 ca_mgm)
# Maintainer: Dehai Kong <dhkong@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

my $password = $testapi::password;
my $email    = "you\@example.com";

sub restart_yast2_camgm {
    assert_and_click("xterm-selected");
    type_string("yast2 ca_mgm\n");
    wait_still_screen 1;
    assert_screen("yast2-ca_management-testca");
    send_key("alt-t");
    wait_still_screen 1;
    type_string("$password");
    send_key("alt-o");
    assert_screen("yast2-ca_management-description-for-testca");
}

sub ending_yast2_camgm {
    send_key("alt-o");
    save_screenshot;
    send_key("alt-f");
    save_screenshot;
}

sub run {
    # Create a Root CA
    x11_start_program("xterm");
    become_root;
    pkcon_quit;
    wait_still_screen 1;
    zypper_call("in libcamgm100 perl-camgm yast2-ca-management");
    wait_still_screen 2;
    type_string("clear\n");
    save_screenshot;
    type_string("yast2 ca_mgm\n");
    wait_still_screen 2;
    assert_screen("yast2-ca-management");

    send_key("alt-c");
    type_string("TestCA");
    save_screenshot;
    send_key("alt-m");
    type_string("Example CA");
    save_screenshot;
    send_key("tab");
    send_key("tab");
    type_string("$email");
    send_key("alt-a");
    save_screenshot;
    send_key("alt-i");
    type_string("SUSE");
    save_screenshot;
    send_key("alt-g");
    type_string("QA");
    save_screenshot;
    send_key("alt-l");
    type_string("PEK");
    save_screenshot;
    send_key("alt-s");
    type_string("PEK");
    save_screenshot;
    send_key("alt-o");
    type_string("CN");
    save_screenshot;

    send_key("alt-n");
    wait_still_screen 1;
    type_string("$password");
    send_key("alt-i");
    type_string("$password");
    save_screenshot;
    send_key("alt-n");
    save_screenshot;
    send_key("alt-t");
    send_key("alt-f");
    save_screenshot;

    # Create User Certificates
    restart_yast2_camgm;
    ## Create ServerCA
    send_key("alt-c");
    save_screenshot;
    send_key("alt-a");
    save_screenshot;
    send_key("alt-a");
    save_screenshot;
    send_key("alt-c");
    type_string("ServerCA");
    save_screenshot;
    send_key("tab");
    send_key("tab");
    type_string("$email\n");
    save_screenshot;
    wait_still_screen 1;
    send_key("alt-u");
    save_screenshot;
    send_key("alt-n");
    save_screenshot;
    send_key("alt-t");
    assert_screen("yast2-ca_management-serverca-created");
    ## Create ClientCA
    send_key("alt-a");
    save_screenshot;
    send_key("alt-d");
    save_screenshot;
    send_key("alt-c");
    type_string("ClientCA");
    save_screenshot;
    send_key("tab");
    send_key("tab");
    type_string("$email\n");
    save_screenshot;
    wait_still_screen 1;
    send_key("alt-u");
    save_screenshot;
    send_key("alt-n");
    save_screenshot;
    send_key("alt-t");
    assert_screen("yast2-ca_management-clientca-created");
    ending_yast2_camgm;

    # Revoke unwanted certificates
    restart_yast2_camgm;
    send_key("alt-c");
    save_screenshot;
    ## Revoke ServerCA
    send_key("alt-k");
    save_screenshot;
    send_key("alt-o");
    assert_screen("yast2-ca_management-revoked-serverca");
    ending_yast2_camgm;

    # Create Certificate Revocation Lists (CRLs)
    restart_yast2_camgm;
    send_key("alt-l");
    save_screenshot;
    send_key("alt-g");
    save_screenshot;
    send_key("alt-o");
    save_screenshot;
    assert_screen("yast2-ca_management-certificate-revocation-list");
    ending_yast2_camgm;

    # Exporting CA Objects as a File
    restart_yast2_camgm;
    ## Export ClientCA
    send_key("alt-c");
    assert_and_click("yast2-ca_management-clientca-created");
    send_key("alt-x");
    save_screenshot;
    send_key("alt-e");
    save_screenshot;
    send_key("alt-p");
    type_string("$password");
    send_key("alt-f");
    type_string("\/root\/ClientCA.crt\n");
    save_screenshot;
    send_key("alt-o");
    save_screenshot;
    send_key("alt-o");
    save_screenshot;
    ending_yast2_camgm;
    ## Check export CA file
    assert_and_click("xterm-selected");
    type_string("file \/root\/ClientCA.crt\n");
    save_screenshot;
    type_string("cat \/root\/ClientCA.crt\n");
    save_screenshot;

    # Cleanup
    assert_and_click("xterm-selected");
    type_string("rm -f \/root\/ClientCA.crt\n");
    save_screenshot;
    send_key("alt-f4");
}

sub test_flags {
    return {fatal => 1};
}

1;
