# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot windows image for the first time and provide basic user environment configuration
# Maintainer: QAC team <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;

sub run {
    my $self = shift;

    assert_screen 'windows-start-with-region', 360;
    assert_and_click 'windows-yes';
    assert_screen 'windows-keyboard-layout-page',                    180;
    send_key_until_needlematch 'windows-keyboard-layout-english-us', 'down';
    assert_and_click 'windows-yes';
    assert_screen 'windows-second-keyboard';
    assert_and_click 'windows-skip-second-keyboard';
    # Network setup takes ages
    assert_screen 'windows-account-setup', 360;
    assert_and_click 'windows-select-personal-use', dclick => 1;
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-next';
    assert_screen 'windows-signin-with-ms', 60;
    assert_and_click 'windows-offline';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-limited-exp', timeout => 60;
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-create-account';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    type_string $realname;
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    save_screenshot;
    assert_and_click 'windows-next';
    for (1 .. 2) {
        sleep 3;
        type_password;
        save_screenshot;
        assert_and_click 'windows-next';
    }
    for (1 .. 3) {
        sleep 3;
        assert_and_click 'windows-security-question';
        send_key 'down';
        send_key 'ret';
        send_key 'tab';
        sleep 1;
        type_string 'security';
        sleep 3;
        assert_and_click 'windows-next';
    }

    my $count        = 0;
    my @privacy_menu = split(',', get_required_var('WIN_INSTALL_PRIVACY_NEEDLES'));
    foreach my $tag (@privacy_menu) {
        send_key('pgdn') if (++$count == 4);
        assert_and_click $tag;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    }
    assert_and_click 'windows-accept';

    assert_screen 'windows-make-cortana-personal-assistant';
    assert_and_click 'windows-accept';

    assert_screen([qw(windows-desktop windows-edge-decline networks-popup-be-discoverable)], 600);

    if (match_has_tag 'network-popup-be-discoverable') {
        assert_and_click 'network-discover-yes';
        wait_screen_change(sub { send_key 'ret' }, 10);
    }

    if (match_has_tag 'windows-edge-decline') {
        assert_and_click 'windows-edge-decline';
    }

    assert_screen 'windows-desktop';

    # setup stable lock screen background
    $self->use_search_feature('lock screen settings');
    assert_screen 'lock-screen-in-search';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'lock-screen-in-search', dclick => 1;
    assert_screen 'lock-screen-settings';
    assert_and_click 'lock-screen-background';
    assert_and_click 'select-picture';

    # turn off hibernation and fast startup
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => q{Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -Value 0});
    $self->run_in_powershell(cmd => 'powercfg /hibernate off');
    # disable screen's fade to black
    $self->run_in_powershell(cmd => 'powercfg -change -monitor-timeout-ac 0');
    # adjust visusal effects to best performance
    $self->run_in_powershell(cmd => q{Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Value 2});
    # remove skype and xbox
    $self->run_in_powershell(cmd => 'Get-AppxPackage -allusers Microsoft.SkypeApp | Remove-AppxPackage');
    $self->run_in_powershell(cmd => 'Get-AppxPackage -allusers Microsoft.XboxApp | Remove-AppxPackage');
    $self->run_in_powershell(cmd => 'Get-AppxPackage -allusers Microsoft.XboxGamingOverlay | Remove-AppxPackage');
    $self->run_in_powershell(cmd => 'Get-AppxPackage -allusers Microsoft.YourPhone | Remove-AppxPackage');
    # remove cortana
    $self->run_in_powershell(cmd => 'Get-AppxPackage -allusers Microsoft.549981C3F5F10 | Remove-AppxPackage');

    # poweroff
    $self->reboot_or_shutdown();
}

1;
