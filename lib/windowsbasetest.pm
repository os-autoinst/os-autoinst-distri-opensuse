# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

package windowsbasetest;
use Mojo::Base qw(basetest);
use Utils::Architectures qw(is_aarch64);
use testapi;

sub windows_run {
    my ($self, $cmd) = @_;
    send_key 'super-r';
    wait_still_screen;
    send_key 'backspace';
    assert_screen 'windows-run';
    enter_cmd $cmd;
    wait_still_screen;
}

sub _setup_serial_device {
    type_string '$port = new-Object System.IO.Ports.SerialPort COM1,9600,None,8,one', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    type_string '$port.open()', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    type_string '$port.WriteLine("Serial Port has been opened...")', max_interval => 125;
    wait_screen_change(sub { send_key 'ret' }, 10);
    wait_serial 'Serial Port has been opened...';
}

sub use_search_feature {
    my ($self, $string_to_search) = @_;
    return unless ($string_to_search);

    send_key_until_needlematch "windows-search-bar", 'super-s';
    wait_still_screen stilltime => 2, timeout => 15;
    type_string "$string_to_search ", max_interval => 100, wait_still_screen => 0.5;
}

sub select_windows_in_grub2 {
    return unless (get_var('DUALBOOT'));

    assert_screen "grub-reboot-windows", 125;
    send_key "down" for (1 .. 2);
    send_key "ret";
}

sub open_powershell_as_admin {
    my ($self, %args) = @_;

    #If using windows server, and logged with Administrator, only open powershell
    if (get_var('QAM_WINDOWS_SERVER')) {
        send_key_until_needlematch 'windows-quick-features-menu', 'super-x';
        wait_screen_change { send_key('shift-a') };
        wait_screen_change { assert_and_click('window-max') };
        assert_screen 'windows_server_powershell_opened', 30;
    } else {
        if (check_var('WIN_VERSION', '10')) {
            send_key_until_needlematch 'windows-quick-features-menu', 'super-x';
            wait_screen_change { send_key('shift-a') };
        } elsif (check_var('WIN_VERSION', '11')) {
            # In Win11 there's need to launch PowerShell from "Run command", as
            # "Quick features menu" fails sometimes.
            send_key_until_needlematch 'run-command-window', 'super-r';
            wait_screen_change { type_string 'Powershell' };
            # Ctrl+Shift+Return launchs command as Admin
            send_key 'ctrl-shift-ret';
        } else {
            die("WIN_VERSION variable does not match '10' neither '11'!");
        }
        assert_screen(["windows-user-account-ctl-hidden", "windows-user-acount-ctl-allow-make-changes"], 240);
        assert_and_click "windows-user-account-ctl-hidden" if match_has_tag("windows-user-account-ctl-hidden");
        assert_and_click "windows-user-acount-ctl-yes";
        wait_still_screen stilltime => 3, timeout => 12;
        if (check_var('WIN_VERSION', '11')) {
            # When opening Powershell, sometimes the startup menu window pops up.
            assert_screen(['powershell-with-startup-menu', 'powershell-as-admin-window'], 240);
            send_key 'esc' if match_has_tag('powershell-with-startup-menu');
        }
        assert_screen 'powershell-as-admin-window', timeout => 240;
        assert_and_click 'window-max';
        wait_still_screen stilltime => 3, timeout => 12;
        _setup_serial_device unless (exists $args{no_serial});
    }
}

sub run_in_powershell {
    my ($self, %args) = @_;
    my $rc_hash = testapi::hashed_string $args{cmd};

    type_string $args{cmd}, max_interval => 125;

    if (exists $args{code} && (ref $args{code} eq 'CODE')) {
        wait_screen_change(sub { send_key 'ret' }, 10);
        $args{code}->();
        send_key 'ctrl-l';
    } elsif (get_var('QAM_WINDOWS_SERVER')) {
        save_screenshot;
        wait_screen_change(sub { send_key 'ret' }, 10);
        assert_screen($args{tags});
        return;
    } else {
        type_string ';$port.WriteLine(\'' . $rc_hash . '\' + $?)', max_interval => 125;
        wait_screen_change(sub { send_key 'ret' }, 10);
        wait_serial("${rc_hash}True", timeout => (exists $args{timeout}) ? $args{timeout} : 60) or
          die "Expected string (${rc_hash}True) was not found on serial";
    }
}

sub reboot_or_shutdown {
    my ($self, $is_reboot) = @_;
    send_key_until_needlematch 'ms-quick-features', 'super-x';
    wait_screen_change(sub { send_key 'u' }, 10);
    sleep 1;
    wait_screen_change(sub { send_key((!!$is_reboot) ? 'r' : 'u') }, 10);
    #if using windows server
    if (get_var('QAM_WINDOWS_SERVER')) {
        send_key 'ret';
    }

    save_screenshot;
    assert_shutdown unless ($is_reboot);
}

sub wait_boot_windows {

    my ($self, $is_firstboot) = @_;

    # Reset the consoles: there is no user logged in anywhere
    reset_consoles;
    assert_screen 'windows-screensaver', 900;
    send_key_until_needlematch 'windows-login', 'esc';
    type_password;
    send_key 'ret';    # press shutdown button
    if ($is_firstboot) {
        record_info('Windows firstboot', 'Starting Windows for the first time');
        wait_still_screen stilltime => 60, timeout => 300;
        # When starting Windows for the first time, several screens or pop-ups may appear
        # in a different order. We'll try to handle them until the desktop is shown
        assert_screen(['windows-desktop', 'windows-edge-decline', 'networks-popup-be-discoverable', 'windows-start-menu', 'windows-qemu-drivers'], timeout => 120);
        while (not match_has_tag('windows-desktop')) {
            assert_and_click 'network-discover-yes' if (match_has_tag 'networks-popup-be-discoverable');
            assert_and_click 'windows-edge-decline' if (match_has_tag 'windows-edge-decline');
            assert_and_click 'windows-start-menu' if (match_has_tag 'windows-start-menu');
            assert_and_click 'windows-qemu-drivers' if (match_has_tag 'windows-qemu-drivers');
            wait_still_screen stilltime => 15, timeout => 60;
            assert_screen(['windows-desktop', 'windows-edge-decline', 'networks-popup-be-discoverable', 'windows-start-menu', 'windows-qemu-drivers'], timeout => 120);
        }

        # TODO: all this part should be added to the unattend XML in the future

        # Setup stable lock screen background
        record_info('Config lockscreen', 'Setup stable lock screen background');
        $self->use_search_feature('lock screen settings');
        assert_screen 'windows-lock-screen-in-search';
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
        assert_and_click 'windows-lock-screen-in-search', dclick => 1;
        assert_screen 'windows-lock-screen-settings';
        assert_and_click 'windows-lock-screen-background';
        assert_and_click 'windows-select-picture';
        assert_and_click 'windows-close-lockscreen';
        # These commands disable notifications that Windows shows randomly and
        # make our windows lose focus
        $self->open_powershell_as_admin;
        $self->run_in_powershell(cmd => 'reg add "HKLM\Software\Policies\Microsoft\Windows" /v Explorer');
        $self->run_in_powershell(cmd => 'reg add "HKLM\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1');
        $self->run_in_powershell(cmd => 'reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0');
        record_info 'Port close', 'Closing serial port...';
        $self->run_in_powershell(cmd => '$port.close()', code => sub { });
        $self->run_in_powershell(cmd => 'exit', code => sub { });
    } else {
        record_info("Win boot", "Windows started properly");
        assert_screen ['finish-setting', 'windows-desktop'], 240;
        if (match_has_tag 'finish-setting') {
            assert_and_click 'finish-setting';
        }
    }
}

sub windows_server_login_Administrator {
    #Login windows Server as Administrator
    send_key "ctrl-alt-delete";
    assert_screen "windows_server_login", timeout => 60;
    type_string "N0tS3cr3t@";
    send_key "ret";
    #some times server_manager windows slow to open when Openqa high load, fix waiting few seconds more...
    assert_screen "wint_manage_server", timeout => 150;
}


sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    sleep 30;
    save_screenshot;
}

sub install_wsl2_kernel {
    my $self = shift;
    my $ms_kernel_link = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi';
    $ms_kernel_link = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi' if is_aarch64;

    # Download the WSL kernel and install it
    $self->run_in_powershell(
        cmd => "Invoke-WebRequest -Uri $ms_kernel_link -O C:\\kernel.msi  -UseBasicParsing",
        timeout => 300
    );
    $self->run_in_powershell(
        cmd => q{ii C:\\kernel.msi},
        code => sub {
            assert_and_click 'wsl2-install-kernel-start', timeout => 60;
            assert_and_click 'wsl2-install-kernel-finished', timeout => 60;
        }
    );
    $self->run_in_powershell(
        cmd => q{wsl --set-default-version 2}
    );
}

sub power_configuration {
    my $self = shift;

    # turn off hibernation and fast startup
    $self->run_in_powershell(cmd =>
          q{Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0}
    );
    $self->run_in_powershell(cmd => 'powercfg /hibernate off');

    # disable screen's fade to black
    $self->run_in_powershell(cmd => 'powercfg -change -monitor-timeout-ac 0');

    # adjust visual effects to best performance
    $self->run_in_powershell(cmd =>
          q{Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -Value 2}
    );
}

1;
