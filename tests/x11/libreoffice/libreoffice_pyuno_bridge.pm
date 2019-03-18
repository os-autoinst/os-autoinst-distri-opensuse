# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case 1503978 - LibreOffice: pyuno bridge
# Maintainer: Jiawei Sun <JiaWei.Sun@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my $self     = shift;
    my $mail_ssl = '1';     #Set it as 1, if you want enable SSL

    my $config        = $self->getconfig_emailaccount;
    my $mailbox       = $config->{internal_account_A}->{mailbox};
    my $mail_server   = $config->{internal_account_A}->{sendServer};
    my $mail_user     = $config->{internal_account_A}->{user};
    my $mail_passwd   = $config->{internal_account_A}->{passwd};
    my $mail_sendport = $config->{internal_account_A}->{sendport};

    x11_start_program('libreoffice --writer', target_match => 'test-ooffice-1');
    #Open the mail Merge Email dialog
    send_key "alt-t";
    assert_screen('libreoffice-tool-droplist', 30);
    send_key "alt-o";
    assert_screen('libreoffice-options-menu', 30);
    assert_and_dclick('liberoffice-options-menu-LiberOfficeWriter');
    send_key_until_needlematch "liberoffice-mail-Merge", "down", 20, 3;    #find Mail Merge E-mail

    #fill the information and click test_setting button
    send_key "alt-y";
    type_string "$mail_user";
    send_key "alt-e";
    type_string "$mailbox";
    send_key "alt-s";
    type_string "$mail_server";
    send_key "alt-p";
    type_string "$mail_sendport";
    if ($mail_ssl == 1) {
        send_key "alt-u";
    }
    #Open Serer Authentication and input User$Password
    assert_and_click('libreoffice-server-authentication');
    assert_screen('Server-setting', 30);
    send_key "alt-t";
    send_key "alt-u";
    type_string "$mail_user";
    send_key "alt-p";
    type_string "$mail_passwd";
    send_key "alt-o";
    #Test setting
    #wait_screen_chang {
    #	send_key "alt-e";
    #};
    assert_screen('liberoffice-mail-Merge', 30);
    assert_and_click('libreoffice-mail-testsettings');
    assert_screen('liberoffice-mailmerge-testAccount', 30);
    #exit libreoffice
    send_key "alt-c";
    send_key "alt-o";
    send_key "ctrl-q";
}

1;
