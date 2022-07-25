# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

package windowsbasetest;
use Mojo::Base qw(basetest);
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

    send_key_until_needlematch "windows-quick-features-menu", 'super-x';
    wait_still_screen stilltime => 2, timeout => 15;
    #If using windows server, and logged with Administrator, only open powershell
    if (get_var('QAM_WINDOWS_SERVER')) {
        send_key 'shift-a';
        wait_screen_change { assert_and_click('window-max') };
        assert_screen 'windows_server_powershel_opened', 30;
    } else {
        send_key 'shift-a';
        assert_screen(["windows-user-account-ctl-hidden", "windows-user-acount-ctl-allow-make-changes"], 240);
        mouse_set(500, 500);
        assert_and_click "windows-user-account-ctl-hidden" if match_has_tag("windows-user-account-ctl-hidden");
        assert_and_click "windows-user-acount-ctl-yes";
        mouse_hide();
        wait_still_screen stilltime => 2, timeout => 15;
        if (check_var('VERSION', '11')) {
            # Screen resolution differs in Win11 and the max. button is out of
            # sight, so we dclick on the window bar to maximize
            assert_and_dclick 'powershell-as-admin-window';
        } else {
            assert_screen 'powershell-as-admin-window', 240;
            assert_and_click 'window-max';
        }
        sleep 3;
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
        wait_serial("${rc_hash}True", timeout => (exists $args{timeout}) ? $args{timeout} : 30) or
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
    # Reset the consoles: there is no user logged in anywhere
    reset_consoles;

    assert_screen 'windows-screensaver', 600;
    send_key_until_needlematch 'windows-login', 'esc';
    type_password;
    send_key 'ret';    # press shutdown button

    assert_screen 'windows-desktop', 240;
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
}

1;
