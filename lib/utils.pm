package utils;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/
  check_console_font
  clear_console
  is_jeos
  select_kernel
  type_string_slow
  type_string_very_slow
  unlock_if_encrypted
  wait_boot
  prepare_system_reboot
  get_netboot_mirror
  zypper_call
  fully_patch_system
  workaround_type_encrypted_passphrase
  ensure_unlocked_desktop
  sle_version_at_least
  ensure_fullscreen
  ensure_shim_import
  reboot_gnome
  assert_screen_with_soft_timeout
  is_desktop_installed
  pkcon_quit
  addon_decline_license
  addon_license
  validate_repos
  setup_online_migration
  turn_off_kde_screensaver
  random_string
  /;


# USB kbd in raw mode is rather slow and QEMU only buffers 16 bytes, so
# we need to type very slowly to not lose keypresses.

# arbitrary slow typing speed for bootloader prompt when not yet scrolling
use constant SLOW_TYPING_SPEED => 13;

# type even slower towards the end to ensure no keybuffer overflow even
# when scrolling within the boot command line to prevent character
# mangling
use constant VERY_SLOW_TYPING_SPEED => 4;

sub unlock_if_encrypted {

    return unless get_var("ENCRYPT");

    assert_screen("encrypted-disk-password-prompt", 200);
    type_password;    # enter PW at boot
    send_key "ret";
}

sub turn_off_kde_screensaver() {
    x11_start_program("kcmshell5 screenlocker");
    assert_screen([qw/kde-screenlock-enabled screenlock-disabled/]);
    if (match_has_tag('kde-screenlock-enabled')) {
        assert_and_click('kde-disable-screenlock');
    }
    assert_screen 'screenlock-disabled';
    send_key("alt-o");
}

# makes sure bootloader appears and then boots to desktop resp text
# mode. Handles unlocking encrypted disk if needed.
# arguments: bootloader_time => seconds # now long to wait for bootloader to appear
sub wait_boot {
    my %args            = @_;
    my $bootloader_time = $args{bootloader_time} // 100;
    my $textmode        = $args{textmode};


    # TODO how to register a post fail hook action here in general? E.g. in
    # case the system is stuck in shutting down as in
    # https://openqa.suse.de/tests/621517 or previous

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;

    if (get_var("OFW")) {
        assert_screen "bootloader-ofw", $bootloader_time;
    }
    # reconnect s390
    elsif (check_var('ARCH', 's390x')) {
        my $login_ready = qr/Welcome to SUSE Linux Enterprise Server.*\(s390x\)/;
        if (check_var('BACKEND', 's390x')) {

            console('x3270')->expect_3270(
                output_delim => $login_ready,
                timeout      => 300
            );

            # give the system time to have routes up
            # and start serial grab again
            sleep 30;
            select_console('iucvconn');
        }
        else {
            wait_serial($login_ready, 300);
        }

        # on z/(K)VM we need to re-select a console
        if ($textmode || check_var('DESKTOP', 'textmode')) {
            select_console('root-console');
        }
        else {
            select_console('x11');
        }
    }
    # On Xen PV and svirt we don't see a Grub menu
    elsif (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux') && check_var('BACKEND', 'svirt'))) {
        my @tags = ('grub2');
        push @tags, 'bootloader-shim-import-prompt'   if get_var('UEFI');
        push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');    # LIVETEST won't to do installation and no grub2 menu show up
        if (get_var('ONLINE_MIGRATION')) {
            push @tags, 'migration-source-system-grub2';
        }
        check_screen(\@tags, $bootloader_time);
        if (match_has_tag("bootloader-shim-import-prompt")) {
            send_key "down";
            send_key "ret";
            assert_screen "grub2", 15;
        }
        elsif (match_has_tag("migration-source-system-grub2") or match_has_tag('grub2')) {
            send_key "ret";                                                      # boot to source system
        }
        elsif (get_var("LIVETEST")) {
            # prevent if one day booting livesystem is not the first entry of the boot list
            if (!match_has_tag("boot-live-" . get_var("DESKTOP"))) {
                send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
            }
            send_key "ret";
        }
        elsif (!match_has_tag("grub2")) {
            # check_screen timeout
            die "needle 'grub2' not found";
        }
    }

    unlock_if_encrypted;

    if ($textmode || check_var('DESKTOP', 'textmode')) {
        assert_screen 'linux-login', 200;
        reset_consoles;

        # Without this login name and password won't get to the system. They get
        # lost somewhere. Applies for all systems installed via svirt, but zKVM.
        if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
            wait_idle;
        }

        return;
    }

    mouse_hide();

    if (get_var("NOAUTOLOGIN") || get_var("XDMUSED")) {
        assert_screen 'displaymanager', 200;
        wait_idle;
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string "$username\n";
        }
        # log in
        #assert_screen "dm-password-input", 10;
        elsif (check_var('DESKTOP', 'gnome')) {
            # In GNOME/gdm, we do not have to enter a username, but we have to select it
            send_key 'ret';
        }
        assert_screen 'displaymanager-password-prompt';
        type_string $password. "\n";
    }

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);
}

# 'ctrl-l' does not get queued up in buffer. If this happens to fast, the
# screen would not be cleared
sub clear_console {
    type_string "clear\n";
}

# in some backends we need to prepare the reboot/shutdown
sub prepare_system_reboot {
    if (check_var('BACKEND', 's390x')) {
        console('iucvconn')->kill_ssh;
    }
}

sub select_kernel {
    my $kernel = shift;

    assert_screen 'grub2', 100;
    send_key 'up';    # stop grub2 countdown
    if (check_screen "grub2-$kernel-selected", 2) {    # if requested kernel is selected continue
        send_key 'ret';
    }
    else {                                             # else go to that kernel thru grub2 advanced options
        send_key_until_needlematch 'grub2-advanced-options', 'down';
        send_key 'ret';
        send_key_until_needlematch "grub2-$kernel-selected", 'down';
        send_key 'ret';
    }
    if (get_var('NOAUTOLOGIN')) {
        my $ret = assert_screen 'displaymanager', 200;
        mouse_hide();
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        else {
            send_key 'ret';
            wait_idle;
        }
        type_string "$password";
        send_key 'ret';
    }
}

# 13.2, Leap 42.1, SLE12 GA&SP1 have problems with setting up the
# console font, we need to call systemd-vconsole-setup to workaround
# that
sub check_console_font {
    select_console('root-console');
    # Ensure the echo of input actually happened by using assert_script_run
    assert_script_run "echo Jeder wackere Bayer vertilgt bequem zwo Pfund Kalbshaxen. 0123456789";
    if (check_screen "broken-console-font", 5) {
        assert_script_run("/usr/lib/systemd/systemd-vconsole-setup");
    }
}

sub is_jeos() {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub type_string_slow {
    my ($string) = @_;

    type_string $string, SLOW_TYPING_SPEED;
}

sub type_string_very_slow {
    my ($string) = @_;

    type_string $string, VERY_SLOW_TYPING_SPEED;

    # the bootloader prompt line is very delicate with typing especially when
    # scrolling. We are typing very slow but this could still pose problems
    # when the worker host is utilized so better wait until the string is
    # displayed before continuing
    wait_still_screen 1;
}

sub get_netboot_mirror {
    my $m_protocol = get_var('INSTALL_SOURCE', 'http');
    return get_var('MIRROR_' . uc($m_protocol));
}

# function wrapping 'zypper -n' with allowed return code, timeout and logging facility
# first parammeter is required command , all others are named and provided as hash
# for example : zypper_call("up", exitcode => [0,102,103], log => "zypper.log");
# up -- zypper -n up -- update system
# exitcode -- allowed return code values
# log -- capture log and store it in zypper.log

sub zypper_call {
    my $command          = shift;
    my %args             = @_;
    my $allow_exit_codes = $args{exitcode} || [0];
    my $timeout          = $args{timeout} || 700;
    my $log              = $args{log};

    my $str = hashed_string("ZN$command");

    if ($log) {
        script_run("zypper -n $command | tee /tmp/$log ; echo $str-\${PIPESTATUS}- > /dev/$serialdev", 0);
    }
    else {
        script_run("zypper -n $command; echo $str-\$?- > /dev/$serialdev", 0);
    }

    my $ret = wait_serial(qr/$str-\d+-/, $timeout);

    upload_logs("/tmp/$log") if $log;

    if ($ret) {
        my ($ret_code) = $ret =~ /$str-(\d+)/;
        die "'zypper -n $command' failed with code $ret_code" unless grep { $_ == $ret_code } @$allow_exit_codes;
        return $ret_code;
    }
    die "zypper doesn't return exitcode";
}

sub fully_patch_system {
    # first run, possible update of packager -- exit code 103
    zypper_call('patch --with-interactive -l', exitcode => [0, 102, 103]);
    # second run, full system update
    zypper_call('patch --with-interactive -l', exitcode => [0, 102], timeout => 3500);
}

sub workaround_type_encrypted_passphrase {
    if (check_var('ARCH', 'ppc64le') && (get_var('ENCRYPT') && !get_var('ENCRYPT_ACTIVATE_EXISTING') || get_var('ENCRYPT_FORCE_RECOMPUTE'))) {
        record_soft_failure 'workaround https://fate.suse.com/320901' if sle_version_at_least('12-SP3');
        unlock_if_encrypted;
    }
}

# if stay under tty console for long time, then check
# screen lock is necessary when switch back to x11
# returns without login if any of the tags in param matches
sub ensure_unlocked_desktop {
    my ($extra_tags) = @_;
    $extra_tags //= [];

    # try to stop screenlocker / blanking
    send_key "esc";

    # prevent the still running screen lock from consuming next key press
    wait_still_screen(1);

    my $tags = [];
    # wait for run prompt or screen locker
    push @$tags, @$extra_tags;
    push @$tags, 'generic-desktop';
    push @$tags, 'screenlock';
    push @$tags, 'gnome-screenlock-password';
    assert_screen($tags);

    for my $tag (@$extra_tags) {
        if (match_has_tag $tag) {
            # caller provided tag matched
            # caller needs to deal with it
            return;
        }
    }

    # no screenlocker detected
    if (match_has_tag 'generic-desktop') {
        if (check_var('DESKTOP', 'gnome')) {
            # gnome might show the old 'generic desktop' screen although that is
            # just a left over in the framebuffer but actually the screen is
            # already locked so we have to try something else to check
            # responsiveness.
            # open run command prompt (if screen isn't locked)
            send_key "alt-f2";
            if (check_screen([qw/desktop-runner/])) {
                send_key "esc";
                assert_screen([qw/generic-desktop/]);
                return;
            }
            else {
                assert_screen([qw/gnome-screenlock-password screenlock/]);
            }
        }
        else {
            return;
        }

    }

    # start to unlocking the screenlock
    if (check_var("DESKTOP", "gnome")) {
        if (match_has_tag "screenlock") {
            wait_screen_change {
                send_key "esc";
            };
        }
        unless (get_var("LIVETEST")) {
            send_key "ctrl";    # show gnome screen lock in sle 11
            assert_screen([qw/gnome-screenlock-password/]);
            type_password;
            send_key "ret";
        }
    }
    else {
        if (check_var("DESKTOP", "minimalx")) {
            type_string "$username";
            save_screenshot();
            send_key "ret";
        }
        # clicked the password input field on all DMs
        # make sure the input cursor is in the input field
        assert_and_click "displaymanager-password-prompt";
        type_password;
        send_key "ret";
    }
}

sub sle_version_at_least;

sub sle_version_at_least {
    my ($version) = @_;

    if ($version eq '12-SP1') {
        return !check_var('VERSION', '12');
    }

    if ($version eq '12-SP2') {
        return sle_version_at_least('12-SP1') && !check_var('VERSION', '12-SP1');
    }

    if ($version eq '12-SP3') {
        return sle_version_at_least('12-SP2') && !check_var('VERSION', '12-SP2');
    }

    die "unsupported SLE VERSION $version in check";
}

sub ensure_fullscreen {
    my (%args) = @_;
    $args{tag} //= 'yast2-windowborder';
    # for ssh-X using our window manager we need to handle windows explicitly
    if (check_var('VIDEOMODE', 'ssh-x')) {
        assert_screen($args{tag});
        my $console = select_console("installation");
        $console->fullscreen({window_name => 'YaST2*'});
    }
}

sub ensure_shim_import {
    my (%args) = @_;
    $args{tags} //= [qw/inst-bootmenu bootloader-shim-import-prompt/];
    assert_screen($args{tags}, 15);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
}

sub reboot_gnome {
    wait_idle;
    send_key "ctrl-alt-delete";    # reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        sleep 3;
        type_password;
        sleep 3;
        assert_and_click 'reboot-auth-typed', 'right';    # Extra assert_and_click (with right click) to check the correct number of characters is typed and open up the 'show text' option
        assert_and_click 'reboot-auth-showtext';          # Click the 'Show Text' Option to enable the display of the typed text
        assert_screen 'reboot-auth-correct-password';     # Check the password is correct

        # we need to kill ssh for iucvconn here,
        # because after pressing return, the system is down
        prepare_system_reboot;

        send_key "ret";
    }
    workaround_type_encrypted_passphrase;
}

=head2 assert_screen_with_soft_timeout

  assert_screen_with_soft_timeout($mustmatch [,timeout => $timeout] [, bugref => $bugref] [,soft_timeout => $soft_timeout] [,soft_failure_reason => $soft_failure_reason]);

Extending assert_screen with a soft timeout. When C<$soft_timeout> is hit, a
soft failure is recorded with the message C<$soft_failure_reason> but
assert_screen continues until the (hard) timeout C<$timeout> is hit. This
makes sense when an assert screen should find a screen within a lower time but
still should not fail and continue until the hard timeout, e.g. to discover
performance issues.

Example:

  assert_screen_with_soft_timeout('registration-found', timeout => 300, soft_timeout => 60, bugref => 'bsc#123456');

=cut
sub assert_screen_with_soft_timeout {
    my ($mustmatch, %args) = @_;
    # as in assert_screen
    $args{timeout}             //= 30;
    $args{soft_timeout}        //= 0;
    $args{soft_failure_reason} //= "$args{bugref}: needle(s) $mustmatch not found within $args{soft_timeout}";
    if ($args{soft_timeout}) {
        die "soft timeout has to be smaller than timeout" unless ($args{soft_timeout} < $args{timeout});
        my $ret = check_screen $mustmatch, $args{soft_timeout};
        return $ret if $ret;
        record_soft_failure "$args{soft_failure_reason}";
    }
    return assert_screen $mustmatch, $args{timeout} - $args{soft_timeout};
}

sub is_desktop_installed {
    return get_var("DESKTOP") !~ /textmode|minimalx/;
}

sub pkcon_quit {
    script_run("systemctl mask packagekit; systemctl stop packagekit; while pgrep packagekitd; do sleep 1; done");
}

sub addon_decline_license {
    if (get_var("HASLICENSE")) {
        if (check_screen 'next-button-is-active', 5) {
            send_key $cmd{next};
            assert_screen "license-refuse";
            send_key 'alt-n';    # no, don't refuse agreement
            wait_still_screen 2;
            send_key $cmd{accept};    # accept license
        }
        else {
            wait_still_screen 2;
            send_key $cmd{accept};    # accept license
        }
    }
}

sub addon_license {
    my ($addon)  = @_;
    my $uc_addon = uc $addon;         # variable name is upper case
    if (get_var("BETA_$uc_addon")) {
        assert_screen "addon-betawarning-$addon";
        send_key "ret";
        assert_screen "addon-license-beta";
    }
    else {
        assert_screen "addon-license-$addon";
    }
    addon_decline_license;
    wait_still_screen 2;
    send_key $cmd{next};
}

sub validatelr {
    my ($args) = @_;

    my $alias           = $args->{alias} || "";
    my $product         = $args->{product};
    my $product_channel = $args->{product_channel} || "";
    my $version         = $args->{version};
    if (get_var('ZDUP')) {
        $version = "";
    }
    if (get_var('FLAVOR') =~ m{SAP}) {
        $version .= "-SAP";
    }
    # Live patching and other modules are not per-service pack channel model,
    # so use major version to validate their repos
    if ($product eq 'SLE-Live') {
        $product = 'SLE-Live-Patching';
        $version = '12';
    }
    if ($product eq 'SLE-WSM') {
        $product = 'SLE-Module-Web-Scripting';
        $version = '12';
    }
    diag "validatelr alias:$alias product:$product cha:$product_channel version:$version";

    # Repo is checked for enabled/disabled state. If the information about the
    # expected state is not delivered to validatelr(), we use some heuristics to
    # determine the expected state: If the installation medium is a physical
    # medium and the system is registered to SCC the repo should be disabled
    # if the system is SLE 12 SP2 and later; enabled otherwise, see PR#11460 and
    # FATE#320494.
    my $enabled_repo = $args->{enabled_repo}
      || (($args->{uri} =~ m{(cd|dvd|hd):///} and check_var('SCC_REGISTER', 'installation') and !check_var('VERSION', '12') and !check_var('VERSION', '12-SP1')) ? "No" : "Yes");
    my $uri = $args->{uri};

    if (check_var('DISTRI', 'sle')) {
        # SLES12 does not have 'SLES12-Source-Pool' SCC channel
        unless (($version eq "12") and ($product_channel eq "Source-Pool")) {
            assert_script_run "zypper lr --uri | awk -F '|' -v OFS=' ' '{ print \$2,\$3,\$4,\$NF }' | tr -s ' ' | grep \"$product$version\[\[:alnum:\]\[:punct:\]\]*-*$product_channel $product$version\[\[:alnum:\]\[:punct:\]\[:space:\]\]*-*$product_channel $enabled_repo $uri\"";
        }
    }
}

sub validate_repos {
    my ($version) = @_;
    $version //= get_var('VERSION');

    assert_script_run "zypper lr | tee /dev/$serialdev";
    script_run "clear";
    assert_script_run "zypper lr -d | tee /dev/$serialdev";

    if (check_var('DISTRI', 'sle') and !get_var('STAGING') and sle_version_at_least('12-SP1')) {
        script_run "clear";

        # On SLE we follow "SLE Channels Checking Table"
        # (https://wiki.microfocus.net/index.php?title=SLE12_SP2_Channels_Checking_Table)
        my (%h_addons, %h_addonurl, %h_scc_addons);
        my @addons_keys   = split(/,/, get_var('ADDONS',   ''));
        my @addonurl_keys = split(/,/, get_var('ADDONURL', ''));
        my $scc_addon_str = '';
        for my $scc_addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            $scc_addon =~ s/geo/ha-geo/ if ($scc_addon eq 'geo');
            $scc_addon_str .= "SLE-" . uc($scc_addon) . ',';
        }
        my @scc_addons_keys = split(/,/, $scc_addon_str);
        @h_addons{@addons_keys}         = ();
        @h_addonurl{@addonurl_keys}     = ();
        @h_scc_addons{@scc_addons_keys} = ();

        my $base_product;
        if (check_var('DISTRI', 'sle')) {
            if (get_var('FLAVOR') =~ m{Desktop-DVD}) {
                $base_product = "SLED";
            }
            else {
                $base_product = "SLES";
            }
        }

        # On system with ONLINE_MIGRATION variable set, we don't have SLE media
        # repository of VERSION N but N-1 (i.e. on SLES12-SP2 we have SLES12-SP1
        # repository. For the sake of sanity, the base product repo is not being
        # verified in such a scenario.
        if (!get_var("ONLINE_MIGRATION")) {
            # This is where we verify base product repos for SLES, SLED, and HA
            if (check_var('FLAVOR', 'Server-DVD')) {
                my $uri = "cd:///";
                if (check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw")) {
                    $uri = "http[s]*://.*suse";
                }
                elsif (get_var('USBBOOT')) {
                    $uri = "hd:///.*usbstick";
                }
                elsif (check_var('ARCH', 's390x')) {
                    $uri = "ftp://";
                }
                validatelr(
                    {
                        product      => "SLES",
                        enabled_repo => get_var('ZDUP') ? "No" : undef,
                        uri          => $uri,
                        version      => $version
                    });
            }
            elsif (check_var('FLAVOR', 'SAP-DVD')) {
                validatelr({product => "SLE-", uri => "cd:///", version => $version});
            }
            elsif (check_var('FLAVOR', 'Server-DVD-HA')) {
                validatelr({product => "SLES", uri => "cd:///", version => $version});
                validatelr({product => 'SLE-*HA', uri => get_var('ADDONURL_HA') || "dvd:///", version => $version});
                if (exists $h_addonurl{geo} || exists $h_addons{geo}) {
                    validatelr({product => 'SLE-*HAGEO', uri => get_var('ADDONURL_GEO') || "dvd:///", version => $version});
                }
                delete @h_addonurl{qw/ha geo/};
                delete @h_addons{qw/ha geo/};
            }
            elsif (check_var('FLAVOR', 'Desktop-DVD')) {
                # Note: verification of AMD (SLED12) and NVIDIA (SLED12, SP1, and SP2) repos is missing
                validatelr({product => "SLED", uri => "cd:///", version => $version});
            }
        }

        # URI Addons
        for my $addonurl_prod (keys %h_addonurl) {
            my $addonurl_tmp;
            if ($addonurl_prod eq "sdk") {
                $addonurl_tmp = $addonurl_prod;
            }
            else {
                $addonurl_tmp = "sle" . $addonurl_prod;
            }
            validatelr({product => uc $addonurl_tmp, uri => get_var("ADDONURL_" . uc $addonurl_prod), version => $version});
        }

        # DVD Addons; FATE#320494 (PR#11460): disable installation source after installation if we register system
        for my $addon (keys %h_addons) {
            if ($addon ne "sdk") {
                $addon = "sle" . $addon;
            }
            validatelr(
                {
                    product      => uc $addon,
                    enabled_repo => get_var('SCC_REGCODE_' . uc $addon) ? "No" : "Yes",
                    uri          => "dvd:///",
                    version      => $version
                });
        }

        # Verify SLES, SLED, Addons and their online SCC sources, if SCC_REGISTER is enabled
        if (check_var('SCC_REGISTER', 'installation')) {
            my ($uri, $nvidia_uri, $we);

            # Set uri and nvidia uri for smt registration and others (scc, proxyscc)
            # For smt url variable, we have to use https to import smt server's certification
            # After registration, the uri of smt could be http
            if (get_var('SMT_URL')) {
                ($uri = get_var('SMT_URL')) =~ s/https:\/\///;
                $uri        = "http[s]*://" . $uri;
                $nvidia_uri = $uri;
            }
            else {
                $uri        = "http[s]*://.*suse";
                $nvidia_uri = "http[s]*://.*nvidia";
            }

            for my $scc_product ($base_product, keys %h_scc_addons) {
                $we = 1 if ($scc_product eq "SLE-WE");
                for my $product_channel ("Pool", "Updates", "Debuginfo-Pool", "Debuginfo-Updates", "Source-Pool") {
                    validatelr(
                        {
                            product         => $scc_product,
                            product_channel => $product_channel,
                            enabled_repo    => ($product_channel =~ m{(Debuginfo|Source)}) ? "No" : "Yes",
                            uri             => $uri,
                            version         => $version
                        });
                }
            }

            # Check nvidia repo if SLED or sle-we extension registered
            # For the name of product channel, sle12 uses NVIDIA, sle12sp1 and sp2 use nVidia
            # Consider migration, use regex to match nvidia whether in upper, lower or mixed
            # Skip check AMD/ATI repo since it would be removed from sled12 and sle-we-12, see bsc#984866
            # Skip nvidia on sp1 due to bsc#999538 - at least for now
            if (!check_var('VERSION', '12-SP1') && ($base_product eq "SLED" || $we)) {
                validatelr(
                    {
                        product         => "SLE-",
                        product_channel => 'GA-Desktop-[nN][vV][iI][dD][iI][aA]-Driver',
                        enabled_repo    => "Yes",
                        uri             => $nvidia_uri,
                        version         => $version
                    });
            }
        }

        # zdup upgrade repo verification
        if (get_var('ZDUP')) {
            my $uri;
            if (get_var('TEST') =~ m{zdup_offline}) {
                $uri = "dvd:///";
            }
            else {
                $uri = "ftp://openqa.suse.de/SLE-";
            }
            validatelr(
                {
                    product      => "repo1",
                    enabled_repo => "Yes",
                    uri          => $uri,
                    version      => $version
                });
        }
    }
}

sub setup_online_migration {
    # if source system is minimal installation then boot to textmode
    wait_boot textmode => !is_desktop_installed;
    select_console 'root-console';

    # stop packagekit service
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";

    type_string "chown $username /dev/$serialdev\n";

    # enable Y2DEBUG all time
    type_string "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";

    save_screenshot;
}

sub random_string {
    my ($self, $length) = @_;
    $length //= 4;
    my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);
    return join '', map { @chars[rand @chars] } 1 .. $length;
}

1;

# vim: sw=4 et
