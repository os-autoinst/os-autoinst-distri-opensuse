# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test YaST2 module for software management
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "y2x11test";
use strict;
use testapi;
use version_utils qw(is_sle is_leap is_tumbleweed);

sub sw_single {
    # check menu entries at first, then continue with View, Search, RPM Groups
    # and Installation Summary
    # File - open Load package List
    assert_and_click 'sw_file_open';
    assert_and_click 'sw_file_import';
    assert_and_click 'package-load-package-list_cancel';

    # Package - All packages - Update
    assert_and_click 'sw_package';
    # open menu update if newer version available
    assert_and_click 'all-in-this-list';
    send_key 'tab';
    send_key_until_needlematch 'update-if-newer-version-available', 'down';
    send_key 'ret';
    # make sure that package menu got closed after return
    # otherwise following needle can be matched at wrong place
    assert_screen [qw(all-in-this-list_still-selected sw_configurations)];
    if (match_has_tag 'all-in-this-list_still-selected') {
        mouse_click 'to-close-menu';
    }

    # Configurations - Repositories, Online update
    send_key 'alt-g';
    assert_and_click 'sw_repositories';
    assert_screen 'configured_sw_repo', 90;
    # check PGP keys
    send_key 'alt-g';
    assert_screen 'gpg-public-key-management';
    # cancel here and go back to main menu
    assert_and_click 'configured_sw_gpg_cancel';
    assert_and_click 'configured_sw_repo_cancel';

    # Dependencies
    assert_and_click 'sw_dependencies';
    assert_and_click 'check_now';
    assert_and_click 'all-packages-dependencies-ok';

    # Options - Cleanup when deleting packages
    assert_and_click 'sw_options';
    assert_and_click 'cleanup-when-deleting-packages';

    # Extras - Show Products, Changes, History
    assert_and_click 'sw_extras';
    assert_and_click 'show-products';
    assert_and_click 'Products-ok';
    assert_and_click 'sw_extras';
    assert_and_click 'show-changes';
    assert_and_click 'changed-packages-ok';
    assert_and_click 'sw_extras';
    assert_and_click 'show-history';
    assert_and_click 'History-close';

    # Help - Overview, Symbol, keys
    assert_and_click 'sw_help';
    assert_and_click 'help_overview';
    assert_and_click 'overview-ok';
    assert_and_click 'sw_help';
    assert_and_click 'help-symbols';
    assert_and_click 'symbols-ok';
    assert_and_click 'sw_help';
    assert_and_click 'special-keys-overview';
    assert_and_click 'special-keys-overview-ok';

    # View - Pattern
    assert_and_click 'sw_view';
    assert_and_click 'view_patterns';
    assert_screen 'pattern-list';

    # select a package to install: apache2
    assert_and_click 'sw_search';
    assert_and_click 'search_input';
    type_string 'apache2';
    send_key 'alt-s';
    assert_and_click 'select-and-install';
    assert_screen 'package-selected';

    # RPM Groups - check Package Groups
    assert_and_click 'rpm-groups';
    assert_screen 'groups-list';

    # Installation Summary
    assert_and_click 'installation-summary';
    assert_screen 'summary_details';

    # Cover test cases like automatic changes and unsupported packages
    send_key "alt-a";

    #Done and exit
    assert_screen [qw(automatic-changes installation-report)];
    if (match_has_tag('automatic-changes')) {
        send_key 'alt-o';
        assert_screen [qw(unsupported-packages installation-report)];
        if (match_has_tag('unsupported-packages')) {
            send_key 'alt-o';
            assert_and_click 'sw_finish';
        }
        elsif (match_has_tag('installation-report')) {
            assert_and_click 'sw_finish';
        }
    }
}

sub run {
    my $self = shift;
    $self->launch_yast2_module_x11('sw_single', match_timeout => 120);
    # Leap 15.0 uses a different font than TW atm
    # exclude Leap 15.0 for now untill we find a solution
    if (is_sle('12-SP4+') || is_tumbleweed) {
        sw_single;
    }
    else {
        send_key "alt-a";    # Accept and Exit
    }
}

1;
