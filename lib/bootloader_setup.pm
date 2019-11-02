# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package bootloader_setup;

use base Exporter;
use Exporter;
use strict;
use warnings;
use File::Basename 'basename';
use Time::HiRes 'sleep';
use testapi;
use utils;
use version_utils qw(is_caasp is_jeos is_leap is_sle);
use caasp 'pause_until';
use mm_network;

use backend::svirt qw(SERIAL_TERMINAL_DEFAULT_DEVICE SERIAL_TERMINAL_DEFAULT_PORT SERIAL_CONSOLE_DEFAULT_DEVICE SERIAL_CONSOLE_DEFAULT_PORT);

our @EXPORT = qw(
  add_custom_grub_entries
  boot_grub_item
  stop_grub_timeout
  boot_local_disk
  boot_into_snapshot
  compare_bootparams
  parse_bootparams_in_serial
  pre_bootmenu_setup
  select_bootmenu_more
  select_bootmenu_option
  uefi_bootmenu_params
  bootmenu_default_params
  get_hyperv_fb_video_resolution
  bootmenu_network_source
  bootmenu_remote_target
  specific_bootmenu_params
  remote_install_bootmenu_params
  specific_caasp_params
  select_bootmenu_video_mode
  select_bootmenu_language
  tianocore_enter_menu
  tianocore_select_bootloader
  tianocore_http_boot
  zkvm_add_disk
  zkvm_add_interface
  zkvm_add_pty
  $zkvm_img_path
  set_framebuffer_resolution
  set_extrabootparams_grub_conf
  ensure_shim_import
  GRUB_CFG_FILE
  GRUB_DEFAULT_FILE
  add_grub_cmdline_settings
  change_grub_config
  get_cmdline_var
  grep_grub_cmdline_settings
  grep_grub_settings
  grub_mkconfig
  remove_grub_cmdline_settings
  replace_grub_cmdline_settings
);

our $zkvm_img_path = "/var/lib/libvirt/images";

use constant GRUB_CFG_FILE     => "/boot/grub2/grub.cfg";
use constant GRUB_DEFAULT_FILE => "/etc/default/grub";

# prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then
# 'up' also works in textmode and UEFI menues.
sub stop_grub_timeout {
    send_key 'up';
}

=head2 add_custom_grub_entries

Add custom grub entries with extra kernel parameters.
It adds 3rd line with default options + 4th line with advanced options.
Extra kernel parameters are taken in C<GRUB_PARAM> variable.

e.g.  grub entries before:

    * SLES 15
    * Advanced options for SLES 15
    * Start bootloader from a read-only snapshot

grub entries with C<GRUB_PARAM='ima_policy=tcb'> and calling add_custom_grub_entries:

    * SLES 15
    * Advanced options for SLES 15
    * SLES 15 (ima_policy=tcb)
    * Advanced options for SLES 15 (ima_policy=tcb)
    * Start bootloader from a read-only snapshot

And of course the new entries have C<ima_policy=tcb> added to kernel parameters.

=cut
sub add_custom_grub_entries {
    my $grub_param = get_var('GRUB_PARAM');
    return unless defined($grub_param);
    my $script_old     = "/etc/grub.d/10_linux";
    my $script_new     = "/etc/grub.d/11_linux_openqa";
    my $script_old_esc = $script_old =~ s~/~\\/~rg;
    my $script_new_esc = $script_new =~ s~/~\\/~rg;
    my $cfg_old        = 'grub.cfg.old';

    bmwqemu::diag("Trying to trigger purging old kernels before changing grub menu");
    assert_script_run('[ -x /sbin/purge-kernels ] && /sbin/purge-kernels');

    assert_script_run("cp " . GRUB_CFG_FILE . " $cfg_old");
    upload_logs($cfg_old, failok => 1);

    assert_script_run("cp $script_old $script_new");

    my $cmd = "sed -i -e 's/\\(args=.\\)\\(\\\$4\\)/\\1$grub_param \\2/'";
    $cmd .= " -e 's/\\(Advanced options for %s\\)/\\1 ($grub_param)/'";
    $cmd .= " -e 's/\\(menuentry .\\\$(echo .\\\$title\\)/\\1 ($grub_param)/'";
    $cmd .= " -e 's/\\(menuentry .\\\$(echo .\\\$os\\)/\\1 ($grub_param)/' $script_new";
    assert_script_run($cmd);
    upload_logs($script_new, failok => 1);
    grub_mkconfig();
    upload_logs(GRUB_CFG_FILE, failok => 1);

    my $distro      = (is_sle() ? "SLES" : "openSUSE") . ' \\?' . get_required_var('VERSION');
    my $section_old = "sed -e '1,/$script_old_esc/d' -e '/$script_old_esc/,\$d' $cfg_old";
    my $section_new = "sed -e '1,/$script_new_esc/d' -e '/$script_new_esc/,\$d' " . GRUB_CFG_FILE;
    my $cnt_old     = script_output("$section_old | grep -c 'menuentry .$distro'");
    my $cnt_new     = script_output("$section_new | grep -c 'menuentry .$distro'");
    die("Unexpected number of grub entries: $cnt_new, expected: $cnt_old") if ($cnt_old != $cnt_new);
    $cnt_new = script_output("grep -c 'menuentry .$distro.*($grub_param)' " . GRUB_CFG_FILE);
    die("Unexpected number of new grub entries: $cnt_new, expected: " . ($cnt_old)) if ($cnt_old != $cnt_new);
    $cnt_new = script_output("grep -c 'linux.*/boot/.* $grub_param ' " . GRUB_CFG_FILE);
    die("Unexpected number of new grub entries with '$grub_param': $cnt_new, expected: " . ($cnt_old)) if ($cnt_old != $cnt_new);
}

=head2 boot_grub_item

  boot_grub_item([ $menu1, [ $menu2 ] ]);

Choose custom boot menu entry in grub.
C<$menu1> defines which entry to choose in first boot menu,
optional C<$menu2> defines which entry to choose in second boot menu (makes
sense only when C<$menu1> selects "Advanced options", otherwise it's ignored).

Default value is C<$menu1 = 3, $menu2 = 1>, which boots kernel with extra
parameters (generated by add_custom_grub_entries()) or 3rd option whatever it
is other OS (given that 1st and 2nd grub options are for the default kernel):

Examples:

Boot kernel with extra parameters (generated with add_custom_grub_entries())
or 3rd option whatever it is other OS:

    boot_grub_item();
    boot_grub_item(3);

Boot the default kernel:

    boot_grub_item(1);

Boot the default kernel recovery mode (goes through "Advanced options"):

    boot_grub_item(2, 2);

=cut
sub boot_grub_item {
    my ($menu1, $menu2) = @_;
    $menu1 = 3 unless defined($menu1);
    $menu2 = 1 unless defined($menu2);
    die((caller(0))[3] . " expects integer arguments ($menu1, $menu2)") unless ($menu1 =~ /^\d+\z/ && $menu2 =~ /^\d+\z/);

    assert_screen "grub2";

    for (1 .. ($menu1 - 1)) {
        wait_screen_change { send_key 'down' };
    }
    save_screenshot;
    send_key 'ret';

    for (1 .. ($menu2 - 1)) {
        wait_screen_change { send_key 'down' };
    }
    save_screenshot;
    send_key 'ret';
}


sub boot_local_disk {
    if (get_var('OFW')) {
        # TODO use bootindex to properly boot from disk when first in boot order is cd-rom
        wait_screen_change { send_key 'ret' };
        # Currently the bootloader would bounce back to inst-bootmenu screen after pressing 'ret'
        # on 'local' menu-item, we have to check it and send 'ret' again to make booting properly
        if (check_screen(['bootloader', 'inst-bootmenu'], 30)) {
            record_info 'bounce back to inst-bootmenu, send ret again';
            send_key 'ret';
        }
        my @tags = qw(inst-slof grub2);
        push @tags, 'encrypted-disk-password-prompt' if (get_var('ENCRYPT'));
        assert_screen(\@tags);
        if (match_has_tag 'grub2') {
            diag 'already in grub2, returning from boot_local_disk';
            stop_grub_timeout;
            return;
        }
        if (match_has_tag 'inst-slof') {
            diag 'specifying local disk for boot from slof';
            my $slof = 5;
            $slof += 1 if get_var('VIRTIO_CONSOLE');
            type_string_very_slow "boot /pci\t/sc\t$slof";
            save_screenshot;
        }
        if (match_has_tag 'encrypted-disk-password-prompt') {
            # It is possible to show encrypted prompt directly by pressing 'local' boot-menu
            # Simply return and do enter passphrase operation in checking block of sub wait_boot
            return;
        }
    }
    send_key 'ret';
}

sub boot_into_snapshot {
    send_key_until_needlematch('boot-menu-snapshot', 'down', 10, 5);
    send_key 'ret';
    # assert needle to avoid send down key early in grub_test_snapshot.
    assert_screen 'snap-default' if get_var('OFW');
    # in upgrade/migration scenario, we want to boot from snapshot 1 before migration.
    if ((get_var('UPGRADE') && !get_var('ONLINE_MIGRATION', 0)) || get_var('ZDUP')) {
        send_key_until_needlematch('snap-before-update', 'down', 40, 5);
        save_screenshot;
    }
    # in an online migration
    send_key_until_needlematch('snap-before-migration', 'down', 40, 5) if (get_var('ONLINE_MIGRATION'));
    save_screenshot;
    send_key 'ret';
    # avoid timeout for booting to HDD
    save_screenshot;
    send_key 'ret';
}

sub pre_bootmenu_setup {
    if (get_var("IPXE")) {
        sleep 60;
        return 3;
    }

    # After version 12 the USB storage is set as the default boot device using
    # bootindex. Before 12 it needs to be selected in the BIOS.
    if (isotovideo::get_version() < 12 && get_var("USBBOOT")) {
        assert_screen "boot-menu", 5;
        # support multiple versions of seabios, does not harm to press
        # multiple keys here: seabios<1.9: f12, seabios=>1.9: esc
        send_key((match_has_tag 'boot-menu-esc') ? 'esc' : 'f12');
        assert_screen "boot-menu-usb", 4;
        send_key(2 + get_var("NUMDISKS"));
    }

    return 3 if get_var('BOOT_HDD_IMAGE');
    return 0;
}

sub select_bootmenu_option {
    my ($timeout) = @_;
    assert_screen 'inst-bootmenu', $timeout;
    if (get_var('LIVECD')) {
        # live CDs might have a very short timeout of the initial bootmenu
        # (1-2s with recent kiwi versions) so better stop the timeout
        # immediately before checking more and having an opportunity to type
        # more boot parameters.
        stop_grub_timeout;
    }
    if (get_var('ZDUP') || get_var('ONLINE_MIGRATION')) {
        boot_local_disk;
        return 3;
    }

    if (get_var('UPGRADE')) {
        # OFW has contralily oriented menu behavior
        send_key_until_needlematch 'inst-onupgrade', get_var('OFW') ? 'up' : 'down', 10, 5;
    }
    else {
        if (get_var('PROMO') || get_var('LIVETEST') || get_var('LIVE_INSTALLATION') || get_var('LIVE_UPGRADE')) {
            send_key_until_needlematch 'boot-live-' . get_var('DESKTOP'), 'down', 10, 5;
        }
        elsif (get_var('OFW')) {
            send_key_until_needlematch 'inst-oninstallation', 'up', 10, 5;
        }
        elsif (!get_var('JEOS')) {
            send_key_until_needlematch 'inst-oninstallation', 'down', 10, 5;
        }
    }
    return 0;
}

sub get_extra_boot_params {
    my @params = split ' ', get_var('EXTRABOOTPARAMS');
    return @params;
}

sub get_bootmenu_console_params {
    my ($baud_rate) = shift // '';
    my @params;
    $baud_rate = $baud_rate ? ",$baud_rate" : '';
    # To get crash dumps as text
    push @params, "console=${serialdev}${baud_rate}";

    # See bsc#1011815, last console set as boot parameter is linked to /dev/console
    # and doesn't work if set to serial device. Don't want this on some backends.
    push @params, "console=tty" unless (get_var('BACKEND', '') =~ /ipmi|spvm/);
    return @params;
}

sub uefi_bootmenu_params {
    # assume bios+grub+anim already waited in start.sh
    # in grub2 it's tricky to set the screen resolution
    #send_key_until_needlematch('grub2-enter-edit-mode', 'e', 5, 0.5);
    (is_jeos) ? send_key_until_needlematch('grub2-enter-edit-mode', 'e', 5, 0.5)
      :         send_key 'e';
    for (1 .. 2) { send_key "down"; }
    send_key "end";
    # delete "keep" word
    for (1 .. 4) { send_key "backspace"; }
    # hardcoded the value of gfxpayload to 1024x768
    type_string "1024x768";
    assert_screen "gfxpayload_changed", 10;
    # back to the entry position
    send_key "home";
    for (1 .. 2) { send_key "up"; }
    if (is_jeos) {
        send_key "up";
    }
    sleep 5;
    for (1 .. 4) { send_key "down"; }
    send_key "end";

    if (get_var("NETBOOT")) {
        type_string_slow " install=" . get_netboot_mirror;
        save_screenshot();
    }
    send_key "spc";

    # if(get_var("PROMO")) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if (!is_jeos && check_var('VIDEOMODE', "text")) {
        type_string_slow "textmode=1 ";
    }

    type_string " \\\n";    # changed the line before typing video params
}

# Returns kernel framebuffer configuration we have to
# explicitly set on Hyper-V to get 1024x768 resolution.
sub get_hyperv_fb_video_resolution {
    return 'video=hyperv_fb:1024x768';
}


=head2 get_linuxrc_boot_params

  get_linuxrc_boot_params();

Returns array of strings C<@params> with linurc boot options to enable logging to the serial
console, enable core dumps and set debug level for logging.

=cut
sub get_linuxrc_boot_params {
    my @params;
    push @params, "linuxrc.log=/dev/$serialdev";
    # Enable linuxrc core dumps https://en.opensuse.org/SDB:Linuxrc#p_linuxrccore
    push @params, "linuxrc.core=/dev/$serialdev";
    push @params, "linuxrc.debug=4,trace";
    return @params;
}

sub bootmenu_default_params {
    my (%args) = @_;
    my @params;
    if (get_var('OFW')) {
        # edit menu, wait until we get to grub edit
        wait_screen_change { send_key "e" };
        # go down to kernel entry
        send_key "down";
        send_key "down";
        send_key "down";
        wait_screen_change { send_key "end" };
        wait_still_screen(1);
        # load kernel manually with append
        if (check_var('VIDEOMODE', 'text')) {
            push @params, "textmode=1";
        }
        push @params, "Y2DEBUG=1";
    }
    else {
        # On JeOS and CaaSP we don't have YaST installer.
        push @params, "Y2DEBUG=1" unless is_jeos || is_caasp;

        # gfxpayload variable replaced vga option in grub2
        if (!is_jeos && !is_caasp && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
            push @params, "vga=791";
            my $video = 'video=1024x768';
            $video .= '-16' if check_var('QEMUVGA', 'cirrus');
            push @params, $video;
        }

    }

    if (!get_var("NICEVIDEO")) {
        if (is_caasp) {
            push @params, get_bootmenu_console_params $args{baud_rate};
        }
        elsif (!is_jeos) {
            # make plymouth go graphical
            push @params, "plymouth.ignore-serial-consoles" unless $args{pxe};
            push @params, get_bootmenu_console_params $args{baud_rate};

            # Enable linuxrc logging
            push @params, get_linuxrc_boot_params;
        }
        push @params, get_extra_boot_params();
    }

    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    # Default namescheme 'by-id' for devices is broken on Hyper-V (bsc#1029303),
    # we have to use something else.
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        push @params, get_hyperv_fb_video_resolution;
        push @params, 'namescheme=by-label' unless is_jeos or is_caasp;
    }
    type_string_very_slow(" @params ");
    return @params;
}

sub bootmenu_network_source {
    my @params;
    # set HTTP-source to not use factory-snapshot
    if (get_var("NETBOOT")) {
        if (get_var('OFW')) {
            if (get_var("SUSEMIRROR")) {
                push @params, 'install=http://' . get_var("SUSEMIRROR");
            }
            else {
                push @params, ('kernel=1', 'insecure=1');
            }
        }
        else {
            my $m_protocol = get_var('INSTALL_SOURCE', 'http');
            my $m_mirror   = get_netboot_mirror;
            die "No mirror defined, please set MIRROR_$m_protocol variable" unless $m_mirror;
            # In case of https we have to use boot options and not UI
            if ($m_protocol eq "https") {
                push @params, "install=$m_mirror";
                # Ignore certificate validation
                push @params, 'ssl.certs=0' if (get_var('SKIP_CERT_VALIDATION'));
                # As we use boot options, no extra action is required
                type_string_very_slow(" @params ");
                return @params;
            }

            # fate#322276
            # Point linuxrc to a repomd repository and load the installation system from local medium
            if (($m_protocol eq "http") && (get_var('REMOTE_REPOINST'))) {
                push @params, "install=$m_mirror";
                # Specifies the installation system to use, e.g. from where to load installer
                my $arch = get_var('ARCH');
                push @params, "instsys=disk:/boot/$arch/root";
                type_string_very_slow(" @params ");
                return @params;
            }

            select_installation_source({m_protocol => $m_protocol, m_mirror => $m_mirror});
        }
    }
    type_string_very_slow(" @params ");
    return @params;
}

sub bootmenu_remote_target {
    my @params;
    my $remote = get_var("REMOTE_TARGET");
    if ($remote) {
        my $dns = get_host_resolv_conf()->{nameserver};
        push @params, get_var("NETSETUP") if get_var("NETSETUP");
        push @params, "nameserver=" . join(",", @$dns);
        push @params, ("$remote=1", "${remote}password=$password");
    }
    type_string_very_slow(" @params ");
    return @params;
}

sub select_installation_source {
    my ($args_ref) = @_;
    my $m_protocol = $args_ref->{m_protocol};
    my $m_mirror   = $args_ref->{m_mirror};
    my ($m_server, $m_share, $m_directory);

    # Parse SUSEMIRROR into variables
    if ($m_mirror =~ m{^[a-z]+://([a-zA-Z0-9.-]*)(/.*)$}) {
        ($m_server, $m_directory) = ($1, $2);
        if ($m_protocol eq "smb") {
            ($m_share, $m_directory) = $m_directory =~ /\/(.+?)(\/.*)/;
        }
    }

    # select installation source (http, ftp, nfs, smb)
    send_key "f4";
    assert_screen "inst-instsourcemenu";
    send_key_until_needlematch "inst-instsourcemenu-$m_protocol", 'down';
    send_key "ret";
    assert_screen "inst-instsourcedialog-$m_protocol";

    # Clean server name and path
    if ($m_protocol eq "http") {
        for (1 .. 2) {
            # just type enough backspaces
            for (1 .. 32) { send_key "backspace" }
            send_key "tab";
        }
    }

    # Type variables into fields
    type_string_slow "$m_server\t";
    type_string_slow "$m_share\t" if $m_protocol eq "smb";
    type_string_slow "$m_directory\n";
    save_screenshot;

    # HTTP-proxy
    if (get_var("HTTPPROXY", '') =~ m/([0-9.]+):(\d+)/) {
        my ($proxyhost, $proxyport) = ($1, $2);
        send_key "f4";
        for (1 .. 4) {
            send_key "down";
        }
        send_key "ret";
        type_string_slow "$proxyhost\t$proxyport\n";
        assert_screen "inst-proxy_is_setup";

        # add boot parameters
        # ZYPP... enables proxy caching
    }
}

sub select_bootmenu_more {
    my ($tag, $more) = @_;

    my @params;

    # do not waste time waiting when we already matched
    assert_screen 'inst-bootmenu', 15 unless match_has_tag 'inst-bootmenu';
    stop_grub_timeout;

    # after installation-images 14.210 added a submenu
    if ($more && check_screen 'inst-submenu-more', 0) {
        send_key_until_needlematch('inst-onmore', get_var('OFW') ? 'up' : 'down', 10, 5);
        send_key "ret";
    }
    send_key_until_needlematch($tag, get_var('OFW') ? 'up' : 'down', 10, 3);
    # Redirect linuxrc logs to console when booting from menu: "boot linux system"
    push @params, get_linuxrc_boot_params if get_var('LINUXRC_BOOT');
    if (get_var('UEFI')) {
        send_key 'e';
        send_key 'down' for (1 .. 4);
        send_key 'end';
        # newer versions of qemu on arch automatically add 'console=ttyS0' so
        # we would end up nowhere. Setting console parameter explicitly
        # See https://bugzilla.suse.com/show_bug.cgi?id=1032335 for details
        push @params, 'console=tty1' if get_var('MACHINE') =~ /aarch64/;
        # Hyper-V defaults to 1280x1024, we need to fix it here
        push @params, get_hyperv_fb_video_resolution if check_var('VIRSH_VMM_FAMILY', 'hyperv');
        type_string_very_slow(" @params ");
        save_screenshot;
        send_key 'f10';
    }
    else {
        push @params, get_hyperv_fb_video_resolution if check_var('VIRSH_VMM_FAMILY', 'hyperv');
        type_string_very_slow(" @params ");
        save_screenshot;
        send_key 'ret';
    }
    return @params;
}

sub autoyast_boot_params {
    my @params;
    my $ay_var = get_var("AUTOYAST");
    return @params unless $ay_var;

    my $autoyast_args = 'autoyast=';
    # In case of SUPPORT_SERVER, profiles are available on another VM
    if (get_var('USE_SUPPORT_SERVER')) {
        my $proto = get_var("PROTO") || 'http';
        $autoyast_args .= "$proto://10.0.2.1/";
        $autoyast_args .= 'data/' if $ay_var !~ /^aytests\//;
        $autoyast_args .= $ay_var;
    } elsif ($ay_var !~ /^slp$|:\/\//) {
        $autoyast_args .= data_url($ay_var);    # Getting profile from the worker as openQA asset
    } else {
        $autoyast_args .= $ay_var;              # Getting profile by direct url or slp
    }
    push @params, split ' ', $autoyast_args;
    return @params;
}

sub specific_bootmenu_params {
    my @params;

    if (!check_var('ARCH', 's390x')) {
        my @netsetup;
        my $autoyast = get_var("AUTOYAST", "");
        if ($autoyast || get_var("AUTOUPGRADE") && get_var("AUTOUPGRADE") ne 'local') {
            # We need to use 'ifcfg=*=dhcp' instead of 'netsetup=dhcp' as a default
            # due to BSC#932692 (SLE-12). 'SetHostname=0' has to be set because autoyast
            # profile has DHCLIENT_SET_HOSTNAME="yes" in /etc/sysconfig/network/dhcp,
            # 'ifcfg=*=dhcp' sets this variable in ifcfg-eth0 as well and we can't
            # have them both as it's not deterministic. Don't set on IPMI with net interface defined in SUT_NETDEVICE.
            my $ifcfg = check_var('BACKEND', 'ipmi') ? '' : 'ifcfg=*=dhcp SetHostname=0';
            @netsetup = split ' ', get_var("NETWORK_INIT_PARAM", "$ifcfg");
            push @params, @netsetup;
            push @params, autoyast_boot_params;
        }
        else {
            @netsetup = split ' ', get_var("NETWORK_INIT_PARAM") if defined get_var("NETWORK_INIT_PARAM");    #e.g netsetup=dhcp,all
            push @params, @netsetup;
        }
    }
    if (get_var("AUTOUPGRADE") || get_var("AUTOYAST") && (get_var("UPGRADE_FROM_AUTOYAST") || get_var("UPGRADE"))) {
        push @params, "autoupgrade=1";
    }

    # Boot the system with the debug options if shutdown takes suspiciously long time.
    # Please, see https://freedesktop.org/wiki/Software/systemd/Debugging/#index2h1 for the details.
    # Further actions for saving debug logs are done in 'shutdown/cleanup_before_shutdown' module.
    if (get_var('DEBUG_SHUTDOWN')) {
        push @params, ('systemd.log_level=debug', 'systemd.log_target=kmsg', 'log_buf_len=1M', 'printk.devkmsg=on', 'enforcing=0', 'plymouth.enable=0');
    }

    if (get_var("IBFT") or get_var("WITHISCSI")) {
        push @params, "withiscsi=1";
    }

    if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
        diag "Disabling installer self update";
        push @params, "self_update=0";
    }
    elsif (my $self_update_repo = get_var("INSTALLER_SELF_UPDATE")) {
        push @params, "self_update=$self_update_repo";
        diag "Explicitly enabling installer self update with $self_update_repo";
    }

    if (get_var("FIPS_INSTALLATION")) {
        push @params, "fips=1";
    }

    if (my $kexec_value = get_var("LINUXRC_KEXEC")) {
        push @params, "kexec=$kexec_value";
        record_info('Info', 'boo#990374 - pass kexec to installer to use initrd from FTP');
    }

    if (get_var('DUD')) {
        my @duds = split(/,/, get_var('DUD'));
        foreach my $dud (@duds) {
            if ($dud =~ /^(http|https|ftp):\/\//) {
                push @params, "dud=$dud";
            }
            else {
                push @params, 'dud=' . data_url($dud);
            }
        }
        push @params, 'insecure=1';
    }

    # For leap 42.3 we don't have addon_products screen
    if (addon_products_is_applicable() && is_leap('42.3+')) {
        my $addon_url = get_var("ADDONURL");
        $addon_url =~ s/\+/,/g;
        push @params, "addon=$addon_url";
    }

    if (get_var('ISO_IN_EXTERNAL_DRIVE')) {
        push @params, "install=hd:/install.iso";
    }

    # Return parameters as string of space-separated values, because s390x test
    # modules are using strings but not arrays to combine bootloader parameters.
    if (check_var('ARCH', 's390x')) {
        return " @params ";
    }

    type_string_very_slow " @params " if @params;
    save_screenshot;
    return @params;
}

sub remote_install_bootmenu_params {
    my $params = "";
    if (check_var("VIDEOMODE", "text") || check_var("VIDEOMODE", "ssh-x")) {
        $params .= " ssh=1 ";    # trigger ssh-text installation
    }
    else {
        $params .= " sshd=1 VNC=1 VNCSize=1024x768 VNCPassword=$testapi::password ";
    }

    $params .= "sshpassword=$testapi::password ";

    return $params;
}

sub select_bootmenu_video_mode {
    if (check_var("VIDEOMODE", "text")) {
        send_key "f3";
        send_key_until_needlematch("inst-textselected", "up", 5);
        send_key "ret";
        if (match_has_tag("inst-textselected-with_colormenu")) {
            # The video mode menu was enhanced to support various color profiles
            # Pressing 'ret' only 'toggles' text mode on/off, but no longer closes
            # the menu, as the user might also want to pick a color profile
            # close the menu by pressing 'esc'
            send_key "esc";
        }
    }
}

sub select_bootmenu_language {
    # set language last so that above typing will not depend on keyboard layout
    if (get_var("INSTLANG")) {

        # positions in isolinux language selection ; order matters
        # from cpio -i --to-stdout languages < /mnt/boot/*/loader/bootlogo
        my @isolinuxlangmap = qw(
          af_ZA
          ar_EG
          ast_ES
          bn_BD
          bs_BA
          bg_BG
          ca_ES
          cs_CZ
          cy_GB
          da_DK
          de_DE
          et_EE
          en_GB
          en_US
          es_ES
          fa_IR
          fr_FR
          gl_ES
          ka_GE
          gu_IN
          el_GR
          hi_IN
          id_ID
          hr_HR
          it_IT
          he_IL
          ja_JP
          jv_ID
          km_KH
          ko_KR
          ky_KG
          lo_LA
          lt_LT
          mr_IN
          hu_HU
          mk_MK
          nl_NL
          nb_NO
          nn_NO
          pl_PL
          pt_PT
          pt_BR
          pa_IN
          ro_RO
          ru_RU
          zh_CN
          si_LK
          sk_SK
          sl_SI
          sr_RS
          fi_FI
          sv_SE
          tg_TJ
          ta_IN
          th_TH
          vi_VN
          zh_TW
          tr_TR
          uk_UA
          wa_BE
          xh_ZA
          zu_ZA
        );
        my $n;
        my %isolinuxlangmap = map { lc($_) => $n++ } @isolinuxlangmap;
        $n = $isolinuxlangmap{lc(get_var("INSTLANG"))};
        my $en_us = $isolinuxlangmap{en_us};

        if ($n && $n != $en_us) {
            $n -= $en_us;
            send_key "f2";
            assert_screen "inst-languagemenu";
            for (1 .. abs($n)) {
                send_key($n < 0 ? "up" : "down");
            }
            send_key "ret";
        }
    }
}

sub specific_caasp_params {
    return unless is_caasp && get_var('STACK_ROLE');

    # Wait for supportserver (controller node)
    if (!check_var 'STACK_ROLE', 'controller') {
        pause_until 'support_server_ready';
    }

    if (check_var('STACK_ROLE', 'worker')) {
        # Wait until admin node genarates autoyast profile
        pause_until 'VELUM_CONFIGURED' if get_var('AUTOYAST');
        # Wait until first round of nodes are processed
        pause_until 'NODES_ACCEPTED' if get_var('DELAYED');
    }
}

sub tianocore_enter_menu {
    # we need to reduce this waiting time as much as possible
    while (!check_screen('tianocore-mainmenu', 0, no_wait => 1)) {
        send_key 'f2';
        sleep 0.1;
    }
}

sub tianocore_select_bootloader {
    tianocore_enter_menu;
    send_key_until_needlematch('tianocore-bootmanager', 'down', 5, 5);
    send_key 'ret';
}

sub tianocore_http_boot {
    tianocore_enter_menu;
    # Go to Device manager
    send_key_until_needlematch('tianocore-devicemanager', 'down', 5, 5);
    send_key 'ret';
    # In device manager, go to 'Network Device List'
    send_key_until_needlematch('tianocore-devicemanager-networkdevicelist', 'up', 5, 5);
    send_key 'ret';
    # In 'Network Device List', go to first MAC addr
    send_key 'ret';
    # Go to 'HTTP Boot Configuration'
    send_key_until_needlematch('tianocore-devicemanager-networkdevicelist-mac-httpbootconfig', 'up', 5, 5);
    send_key 'ret';
    # Select 'Boot URI'
    send_key_until_needlematch('tianocore-devicemanager-networkdevicelist-mac-httpbootconfig-booturi', 'up', 5, 5);
    send_key 'ret';
    # Enter URI (full URI to EFI file)
    my $arch = get_var("ARCH");
    my $efi_file;
    my $http_prefix = "http://";
    if (get_var('UEFI_HTTPS_BOOT')) {
        $http_prefix = "https://";
    }
    if ($arch =~ /aarch64/) {
        $efi_file = "bootaa64.efi";
    }
    elsif ($arch =~ /x86_64/) {
        $efi_file = "bootx64.efi";
    }
    else {
        die "Unsupported architecture: $arch";
    }
    type_string($http_prefix . get_var('SUSEMIRROR') . "/EFI/BOOT/" . $efi_file);
    send_key 'ret';
    # Save config
    send_key 'f10';
    # Confirm save
    assert_screen('tianocore-devicemanager-networkdevicelist-mac-httpbootconfig-booturi-save');
    send_key 'y';
    # Go back to main menu
    send_key 'esc';
    send_key 'esc';
    send_key 'esc';
    send_key 'esc';
    # Select 'Boot manager' entry
    send_key_until_needlematch('tianocore-bootmanager', 'down', 5, 5);
    send_key 'ret';
    # Select 'UEFI Http' entry
    send_key_until_needlematch('tianocore-bootmanager-uefihttp', 'up', 5, 5);
    send_key 'ret';
}

sub zkvm_add_disk {
    my ($svirt) = @_;
    if (my $hdd = get_var('HDD_1')) {
        my $basename = basename($hdd);
        my $basedir  = svirt_host_basedir();
        my $hdd_dir  = "$basedir/openqa/share/factory/hdd";
        my $hdd_path = $svirt->get_cmd_output("find $hdd_dir -name $basename | head -n1 | tr -d '\n'");
        die "Unable to find image $basename in $hdd_dir" unless $hdd_path;
        diag("HDD path found: $hdd_path");
        if (get_var('PATCHED_SYSTEM')) {
            diag('in patched systems just load the patched image');
            my $name        = $svirt->name;
            my $patched_img = "$zkvm_img_path/$name" . "a.img";
            $svirt->add_disk({file => $patched_img, dev_id => 'a'});
        }
        else {
            type_string("# copying image...\n");
            $svirt->add_disk({file => $hdd_path, backingfile => 1, dev_id => 'a'});    # Copy disk to local storage
        }
    }
    else {
        # Add new disks according to NUMDISKS
        my $size_i   = get_var('HDDSIZEGB') || '4';
        my $numdisks = get_var('NUMDISKS')  || '1';
        my $dev_id   = 'a';
        foreach my $n (1 .. $numdisks) {
            $svirt->add_disk({size => $size_i . "G", create => 1, dev_id => $dev_id});
            # apply next letter as dev_id
            $dev_id = chr((ord $dev_id) + 1);
        }
    }
}

sub zkvm_add_pty {
    my ($svirt) = shift;

    # serial console used for the serial log
    $svirt->add_pty({
            pty_dev      => SERIAL_CONSOLE_DEFAULT_DEVICE,
            pty_dev_type => 'pty',
            target_type  => 'sclp',
            target_port  => SERIAL_CONSOLE_DEFAULT_PORT});

    # sut-serial (serial terminal: emulation of QEMU's virtio console for svirt)
    $svirt->add_pty({
            pty_dev      => SERIAL_TERMINAL_DEFAULT_DEVICE,
            pty_dev_type => 'pty',
            target_type  => 'virtio',
            target_port  => SERIAL_TERMINAL_DEFAULT_PORT});
}

sub zkvm_add_interface {
    my ($svirt) = shift;
    # temporary use of hardcoded '+4' to workaround messed up network setup on z/KVM
    my $vtap   = $svirt->instance + 4;
    my $netdev = get_required_var('NETDEV');
    my $mac    = get_required_var('VIRSH_MAC');
    # direct access to the tap device, use of $vtap temporarily
    $svirt->add_interface({type => 'direct', source => {dev => $netdev, mode => 'bridge'}, target => {dev => 'macvtap' . $vtap}, mac => {address => $mac}});
}

# On Hyper-V and Xen PV we need to add special framebuffer provisions
sub set_framebuffer_resolution {
    my $video;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $video = 'video=hyperv_fb:1024x768';
    }
    elsif (check_var('VIRSH_VMM_TYPE', 'linux')) {
        $video = 'xen-fbfront.video=32,1024,768 xen-kbdfront.ptr_size=1024,768';
    }
    else {
        return;
    }
    add_grub_cmdline_settings($video) if ($video);
}

# Add content of EXTRABOOTPARAMS to /etc/default/grub. Don't forget to run grub2-mkconfig
# in test code afterwards.
sub set_extrabootparams_grub_conf {
    if (my $extrabootparams = get_var('EXTRABOOTPARAMS')) {
        add_grub_cmdline_settings($extrabootparams);
    }
}

sub ensure_shim_import {
    my (%args) = @_;
    $args{tags} //= [qw(inst-bootmenu bootloader-shim-import-prompt)];
    # aarch64 firmware 'tianocore' can take longer to load
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 90 : 30;
    assert_screen($args{tags}, $bootloader_timeout);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
}

=head2 grep_grub_settings

    grep_grub_settings($pattern)

Search for C<$pattern> in /etc/default/grub, return 1 if found.
=cut
sub grep_grub_settings {
    die((caller(0))[3] . ' expects 1 arguments') unless @_ == 1;
    my $pattern = shift;
    return !script_run("grep \"$pattern\" " . GRUB_DEFAULT_FILE);
}

=head2 grep_grub_cmdline_settings

    grep_grub_cmdline_settings($pattern [, $search])

Search for C<$pattern> in grub cmdline variable (usually
GRUB_CMDLINE_LINUX_DEFAULT) in /etc/default/grub, return 1 if found.
=cut
sub grep_grub_cmdline_settings {
    my ($pattern, $search) = @_;
    $search //= get_cmdline_var();
    return grep_grub_settings($search . ".*${pattern}");
}

=head2 change_grub_config

    change_grub_config($old, $new [, $search ] [, $modifiers ], [, $update_grub ]);

Replace C<$old> with C<$new> in /etc/default/grub, using sed.
C<$search> meant to be for changing only particular line for sed,
C<$modifiers> for sed replacement, e.g. "g".
C<$update_grub> if set, regenerate /boot/grub2/grub.cfg with grub2-mkconfig and upload configuration.
=cut
sub change_grub_config {
    die((caller(0))[3] . ' expects from 3 to 5 arguments') unless (@_ >= 3 && @_ <= 5);
    my ($old, $new, $search, $modifiers, $update_grub) = @_;
    $modifiers   //= '';
    $update_grub //= 0;
    $search = "/$search/" if defined $search;

    assert_script_run("sed -ie '${search}s/${old}/${new}/${modifiers}' " . GRUB_DEFAULT_FILE);

    if ($update_grub) {
        grub_mkconfig();
        upload_logs(GRUB_CFG_FILE,     failok => 1);
        upload_logs(GRUB_DEFAULT_FILE, failok => 1);
    }
}

=head2 add_grub_cmdline_settings

    add_grub_cmdline_settings($add [, update_grub => $update_grub] [, search => $search]);

Add C<$add> into /etc/default/grub, using sed.
C<$update_grub> if set, regenerate /boot/grub2/grub.cfg with grub2-mkconfig and upload configuration.
C<$search> if set, bypass default grub cmdline variable.
=cut
sub add_grub_cmdline_settings {
    my $add  = shift;
    my %args = testapi::compat_args(
        {
            add         => $add,
            update_grub => 0,
            search      => get_cmdline_var(),
        }, ['add', 'update_grub', 'search'], @_);

    change_grub_config('"$', " $add\"", $args{search}, "g", $args{update_grub});
}

=head2 add_grub_xen_cmdline_settings

    add_grub_xen_cmdline_settings($add [, $update_grub ]);

Add C<$add> into /etc/default/grub, using sed.
C<$update_grub> if set, regenerate /boot/grub2/grub.cfg with grub2-mkconfig and upload configuration.
=cut
sub add_grub_xen_cmdline_settings {
    my ($add, $update_grub) = @_;
    add_grub_cmdline_settings($add, $update_grub, "GRUB_CMDLINE_XEN_DEFAULT");
}

=head2 replace_grub_cmdline_settings

    replace_grub_cmdline_settings($old, $new [, update_grub => $update_grub] [, search => $search]);

Replace C<$old> with C<$new> in /etc/default/grub, using sed.
C<$update_grub> if set, regenerate /boot/grub2/grub.cfg with grub2-mkconfig and upload configuration.
C<$search> if set, bypass default grub cmdline variable.
=cut
sub replace_grub_cmdline_settings {
    my $old  = shift;
    my $new  = shift;
    my %args = testapi::compat_args(
        {
            old         => $old,
            new         => $new,
            update_grub => 0,
            search      => get_cmdline_var(),
        }, ['old', 'new', 'update_grub', 'search'], @_);
    change_grub_config($old, $new, $args{search}, "g", $args{update_grub});
}

=head2 replace_grub_xen_cmdline_settings

    replace_grub_xen_cmdline_settings($old, $new [, $update_grub ]);

Replace C<$old> with C<$new> in /etc/default/grub, using sed.
C<$update_grub> if set, regenerate /boot/grub2/grub.cfg with grub2-mkconfig and upload configuration.
=cut
sub replace_grub_xen_cmdline_settings {
    my ($old, $new, $update_grub) = @_;
    replace_grub_cmdline_settings($old, $new, $update_grub, "GRUB_CMDLINE_XEN_DEFAULT");
}

=head2 remove_grub_cmdline_settings

    remove_grub_cmdline_settings($remove [, $search]);

Remove C<$remove> from /etc/default/grub (using sed) and regenerate /boot/grub2/grub.cfg.
Search line C<$search> from /etc/default/grub (use for sed).
=cut
sub remove_grub_cmdline_settings {
    my ($remove, $search) = @_;
    replace_grub_cmdline_settings('[[:blank:]]*' . $remove . '[[:blank:]]*', " ", "g", $search);
}

=head2 remove_grub_xen_cmdline_settings

    remove_grub_xen_cmdline_settings($remove);

Remove C<$remove> from /etc/default/grub (using sed) and regenerate /boot/grub2/grub.cfg.
=cut
sub remove_grub_xen_cmdline_settings {
    my $remove = shift;
    remove_grub_cmdline_settings($remove, "GRUB_CMDLINE_XEN_DEFAULT");
}

=head2 grub_mkconfig

    grub_mkconfig();
    grub_mkconfig($config);

Regenerate /boot/grub2/grub.cfg with grub2-mkconfig.
=cut
sub grub_mkconfig {
    my $config = shift;
    $config //= GRUB_CFG_FILE;
    assert_script_run("grub2-mkconfig -o $config");
}

=head2 get_cmdline_var

    get_cmdline_var();

Get default grub cmdline variable:
GRUB_CMDLINE_LINUX for JeOS, GRUB_CMDLINE_LINUX_DEFAULT for the rest.
=cut
sub get_cmdline_var {
    my $label = is_jeos() ? 'GRUB_CMDLINE_LINUX' : 'GRUB_CMDLINE_LINUX_DEFAULT';
    return "^${label}=";
}

=head2 parse_bootparams_in_serial

    parse_bootparams_in_serial();

Parses serail output, searching for 'Command line' parameters. Then converts
the found parameters to an array of the values.

Returns the array of the boot parameters.

=cut

sub parse_bootparams_in_serial {
    my $parsed_string = wait_serial(qr/command line:.*/msi);
    $parsed_string =~ m/.*command line:(?<boot>.*)/i;
    return split ' ', $+{boot};
}

=head2 compare_bootparams

    compare_bootparams(\@array1, \@array2);

Compares two arrays of bootparameters passed by array reference and logs the
result to openQA using record_info.

Does not fail the test module but just highlights the result of the comparison.

=cut

sub compare_bootparams {
    my ($expected_boot_params, $received_boot_params) = @_;
    my @difference = arrays_subset($expected_boot_params, $received_boot_params);
    if (scalar @difference > 0) {
        record_info("params mismatch", "Actual bootloader params do not correspond to the expected ones. Mismatched params: @difference", result => 'fail');
    } else {
        record_info("params ok", "Bootloader parameters are typed correctly.\nVerified parameters: @{$expected_boot_params}");
    }
}

1;
