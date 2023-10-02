# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot windows image for the first time and provide basic user environment configuration
# Maintainer: QAC team <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;

sub run {
    my $self = shift;

    assert_screen 'windows-start-with-region', timeout => 360;
    assert_and_click 'windows-yes';
    assert_screen 'windows-keyboard-layout-page', timeout => 180;
    send_key_until_needlematch 'windows-keyboard-layout-english-us', 'down';
    assert_and_click 'windows-yes';
    assert_screen 'windows-second-keyboard';
    assert_and_click 'windows-skip-second-keyboard';

    # Win11 checks for updates and reboots here so there's need for timeout
    assert_and_click('windows-device-name', timeout => 300)
      if (check_var("WIN_VERSION", "11"));

    # Network setup takes ages
    assert_screen 'windows-account-setup', 360;

    # From 22H2 build, the offline account selection process has diverted a lot
    if (check_var "WIN_VERSION", "11") {
        # There's need to select a work or school account and then choose a
        # domain join in order to skip the MS account
        assert_and_click 'windows-work-school-account', dclick => 1;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
        assert_and_click 'windows-next';
        assert_and_click 'windows-signin-options', timeout => 300;
        assert_and_click 'windows-domain-join';
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;

    }
    else {
        assert_and_click 'windows-select-personal-use', dclick => 1;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
        assert_and_click 'windows-next';
        assert_screen 'windows-signin-with-ms', timeout => 60;
        assert_and_click 'windows-offline';
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
        assert_and_click 'windows-limited-exp', timeout => 60;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    }
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
    my $count = 0;
    my @privacy_menu =
      split(',', get_required_var('WIN_INSTALL_PRIVACY_NEEDLES'));
    foreach my $tag (@privacy_menu) {
        my $version_privacy_needles_scroll = (check_var("WIN_VERSION", "11")) ? 3 : 4;
        send_key('pgdn') if (++$count % $version_privacy_needles_scroll == 0);
        assert_and_click $tag;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    }
    assert_and_click 'windows-accept';

    if (check_screen('windows-custom-experience', timeout => 120)) {
        assert_and_click 'windows-custom-experience';
        assert_screen 'windows-make-cortana-personal-assistant';
        assert_and_click 'windows-accept';
    }

    assert_screen(['windows-desktop', 'windows-edge-decline', 'networks-popup-be-discoverable'], timeout => 600);
    if (match_has_tag 'networks-popup-be-discoverable') {
        assert_and_click 'network-discover-yes';
        wait_screen_change(sub { send_key 'ret' }, timeout => 10);
        assert_screen(['windows-desktop', 'windows-edge-decline']);
    }

    if (match_has_tag 'windows-edge-decline') {
        assert_and_click 'windows-edge-decline';
        assert_screen 'windows-desktop';
    }

    # setup stable lock screen background only in Win10
    $self->use_search_feature('lock screen settings');
    assert_screen 'windows-lock-screen-in-search';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-lock-screen-in-search', dclick => 1;
    assert_screen 'windows-lock-screen-settings';
    assert_and_click 'windows-lock-screen-background';
    assert_and_click 'windows-select-picture';

    # turn off hibernation and fast startup
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd =>
          q{Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0}
    );
    $self->run_in_powershell(cmd => 'powercfg /hibernate off');

    # disable screen's fade to black
    $self->run_in_powershell(cmd => 'powercfg -change -monitor-timeout-ac 0');

    # adjust visusal effects to best performance
    $self->run_in_powershell(cmd =>
          q{Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -Value 2}
    );

    # remove skype and xbox
    $self->run_in_powershell(cmd =>
          'Get-AppxPackage -allusers Microsoft.SkypeApp | Remove-AppxPackage');
    $self->run_in_powershell(cmd =>
          'Get-AppxPackage -allusers Microsoft.XboxApp | Remove-AppxPackage');
    $self->run_in_powershell(cmd =>
          'Get-AppxPackage -allusers Microsoft.XboxGamingOverlay | Remove-AppxPackage'
    );
    $self->run_in_powershell(cmd =>
          'Get-AppxPackage -allusers Microsoft.YourPhone | Remove-AppxPackage'
    );

    # remove cortana
    $self->run_in_powershell(cmd =>
          'Get-AppxPackage -allusers Microsoft.549981C3F5F10 | Remove-AppxPackage'
    );

    # disable 'Let’s finish setting up your device'
    $self->run_in_powershell(cmd =>
          q{New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion' -Name UserProfileEngagement}
    );
    $self->run_in_powershell(cmd =>
          q{New-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Name ScoobeSystemSettingEnabled -Value 0 -Type DWORD}
    );

    # Disables web search in Start menu
    $self->run_in_powershell(
        cmd => 'reg add HKEY_CURRENT_USER\Policies\Microsoft\Windows\Explorer /v DisableSearchBoxSuggestions /t REG_DWORD /d 1'
    );

    # poweroff
    $self->reboot_or_shutdown(1);
    $self->wait_boot_windows;
}

1;
