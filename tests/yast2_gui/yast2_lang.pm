# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_lang.pm checks basic settings of language
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run() {
    my $self   = shift;
    my $module = "language";

    $self->launch_yast2_module_x11($module);
    assert_screen "yast2-$module-ui", 60;

    #	check language details and change detailed locale setting
    assert_and_click 'yast2-lang_details';
    assert_and_click 'yast2-lang_detailed-locale-setting';
    assert_and_click 'yast2-lang_detailed-locale-setting_en_GB';
    assert_screen 'yast2-lang_detailed-locale-setting_changed';
    send_key 'alt-o';

    #	change adapt time zone to German
    assert_and_click 'yast2-lang_adapt-timezone';
    assert_and_click 'yast2-lang_secondary-language';
    assert_screen 'yast2-lang_settings_done';

    #	Now it will install required language packages and exit
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
