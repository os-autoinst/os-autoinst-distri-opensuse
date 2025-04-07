# Copyright 2015-2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package registration;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(is_qemu);
use serial_terminal 'select_serial_terminal';
use utils qw(addon_decline_license assert_screen_with_soft_timeout zypper_call systemctl handle_untrusted_gpg_key quit_packagekit script_retry script_output_retry wait_for_purge_kernels);
use version_utils qw(is_sle is_sles4sap is_upgrade is_leap_migration is_sle_micro is_hpc is_jeos is_transactional is_staging is_agama);
use transactional qw(trup_call process_reboot);
use constant ADDONS_COUNT => 50;
use y2_module_consoletest;
use YaST::workarounds;
use y2_logs_helper qw(accept_license);
use transactional;

our @EXPORT = qw(
  add_suseconnect_product
  remove_suseconnect_product
  cleanup_registration
  register_product
  assert_registration_screen_present
  fill_in_registration_data
  registration_bootloader_cmdline
  registration_bootloader_params
  yast_scc_registration
  skip_registration
  skip_package_hub_if_necessary
  scc_deregistration
  scc_version
  get_addon_fullname
  rename_scc_addons
  is_module
  is_phub_ready
  verify_scc
  investigate_log_empty_license
  register_addons_cmd
  deregister_addons_cmd
  register_addons
  handle_scc_popups
  process_modules
  runtime_registration
  %SLE15_MODULES
  %SLE15_DEFAULT_MODULES
  %ADDONS_REGCODE
  @SLE15_ADDONS_WITHOUT_LICENSE
  @SLE12_MODULES
);

# We already have needles with names which are different we would use here
# As it's only workaround, better not to create another set of needles.
# Add python2 module, refer to https://jira.suse.de/browse/SLE-3167
# Add nvidia compute module, refer to https://jira.suse.com/browse/SLE-16787
our %SLE15_MODULES = (
    base => 'Basesystem',
    sdk => 'Development-Tools',
    desktop => 'Desktop-Applications',
    legacy => 'Legacy',
    script => 'Web-Scripting',
    serverapp => 'Server-Applications',
    contm => 'Containers',
    pcm => 'Public-Cloud',
    sapapp => 'SAP-Applications',
    python2 => 'Python2',
    nvidia => 'NVIDIA-Compute',
);

# The expected modules of a default installation per product. Use them if they
# are not preselected, to crosscheck or just recreate automatic selections
# manually
our %SLE15_DEFAULT_MODULES = (
    sles => 'base,serverapp',
    sled => 'base,desktop',
    sles4sap => 'base,desktop,serverapp,ha,sapapp',
);

our %ADDONS_REGCODE = (
    'sle-ha' => get_var('SCC_REGCODE_HA'),
    'sle-ha-geo' => get_var('SCC_REGCODE_GEO'),
    'sle-we' => get_var('SCC_REGCODE_WE'),
    'sle-module-live-patching' => get_var('SCC_REGCODE_LIVE'),
    'sle-live-patching' => get_var('SCC_REGCODE_LIVE'),
    'SLES-LTSS' => get_var('SCC_REGCODE_LTSS'),
    'SLES-LTSS-Extended-Security' => get_var('SCC_REGCODE_LTSS_ES'),
    'SUSE-Linux-Enterprise-RT' => get_var('SCC_REGCODE_RT'),
    ESPOS => get_var('SCC_REGCODE_ESPOS'),
);

our @SLE15_ADDONS_WITHOUT_LICENSE = qw(ha sdk wsm we hpcm live);
our @SLE15_ADDONS_WITH_LICENSE_NOINSTALL = qw(ha we nvidia);

# Those modules' version is 12 for all of 12 sp products
our @SLE12_MODULES = qw(
  sle-module-adv-systems-management
  sle-module-containers
  sle-module-legacy
  sle-module-toolchain
  sle-module-web-scripting
  sle-module-public-cloud
);

# Set SCC_DEBUG_SUSECONNECT=1 to enable debug output of SUSEConnect globally
my $debug_flag = get_var('SCC_DEBUG_SUSECONNECT') ? '--debug' : '';

# Method to determine if a short name references a module based on what's defined
# on %SLE15_MODULES
sub is_module {
    my $name = shift;
    return defined $SLE15_MODULES{$name};
}

# Check if Packagehub is available
sub is_phub_ready {
    return (check_var('PHUB_READY', '0')) ? 0 : 1;
}

sub accept_addons_license {
    my (@scc_addons) = @_;

    # To check the current state of licenses in the product one can conduct
    # the following steps, e.g. for SLE15:
    #   isc co SUSE:SLE-15:GA 000product
    #   grep -l EULA SUSE:SLE-15:GA/000product/*.product | sed 's/.product//'
    # All shown products have a license that should be checked.
    my @addons_with_license = qw(geo rt idu nvidia);
    # For the legacy module we do not need any additional subscription,
    # like all modules, it is included in the SLES subscription.
    push @addons_with_license, 'lgm' unless is_sle('15+');
    if (is_sle('15+') && get_var('SCC_ADDONS') =~ /ses/ && get_var('BETA')) {
        # during development is license not shown as it was already been shown once
        record_info 'bsc#1118497';
    }
    else {
        push @addons_with_license, 'ses';
    }

    # In SLE 15 some modules do not have license or have the same
    # license (see bsc#1089163) and so are not be shown twice
    push @addons_with_license, @SLE15_ADDONS_WITHOUT_LICENSE unless (is_sle('15+') || is_sle_micro);
    # HA and WE have licenses when calling yast2 scc
    push @addons_with_license, @SLE15_ADDONS_WITH_LICENSE_NOINSTALL if (is_sle('15+') and get_var('IN_PATCH_SLE'));
    # HA does not show EULA when doing migration to 12-SP5
    @addons_with_license = grep { $_ ne 'ha' } @addons_with_license if (is_sle('12-sp5+') && get_var('UPGRADE') && !get_var('IN_PATCH_SLE'));
    # HA does not show EULA when doing migration from 15-SP5 to 15-SP6
    @addons_with_license = grep { $_ ne 'ha' } @addons_with_license if (is_sle('15-sp5+') && get_var('UPGRADE'));

    for my $addon (@scc_addons) {
        # most modules don't have license, skip them
        next unless grep { $addon eq $_ } @addons_with_license;
        while (check_screen('scc-downloading-license', 5)) {
            # wait for SCC to give us the license
            sleep 5;
        }
        assert_screen "scc-addon-license-$addon", 60;
        addon_decline_license;
        wait_still_screen 2;
        send_key $cmd{next};
    }
}

=head2 scc_version

    scc_version([$version]);

Helper for parsing SLE RC version into integer. It replaces SLE version
in format X-SPY into X.Y.
=cut

sub scc_version {
    my $version = shift;
    $version //= get_required_var('VERSION');
    return $version =~ s/-SP/./gr;
}

=head2 add_suseconnect_product

    add_suseconnect_product($name, [$version, [$arch, [$params]]]);

Wrapper for SUSEConnect -p $name.
=cut

sub add_suseconnect_product {
    my ($name, $version, $arch, $params, $timeout, $retry) = @_;
    assert_script_run 'source /etc/os-release';
    $version //= '${VERSION_ID}';
    $arch //= '${CPU}';
    $params //= '';
    $retry //= 3;    # Times we retry the SUSEConnect command (besides first execution)
    $timeout //= 300;

    # some modules on sle12 use major version e.g. containers module
    my $major_version = '$(echo ${VERSION_ID}|cut -c1-2)';
    $version = $major_version if $name eq 'sle-module-containers' && is_sle('<15');
    record_info('SCC product', "Activating product $name");

    my $try_cnt = 0;
    while ($try_cnt++ <= $retry) {
        if (is_transactional) {
            eval { trup_call("register -p $name/" . $version . '/' . get_var('ARCH')) };
        } else {
            eval { assert_script_run("SUSEConnect $debug_flag -p $name/$version/$arch $params", timeout => $timeout); };
        }
        if ($@) {
            record_info('retry', "SUSEConnect failed to activate the module $name. Retrying...");
            sleep 60 * $try_cnt;    # we wait a bit longer for each retry
        }
        else {
            return 1;
        }
    }
    if ($name =~ /PackageHub/ && check_var('BETA', '1')) {
        record_info('INFO', 'PackageHub installation might fail in early development');
    }
    die "SUSEConnect failed activating module $name after $retry retries.";
}

=head2 remove_suseconnect_product

    remove_suseconnect_product($name, [$version, [$arch, [$params]]]);

Wrapper for SUSEConnect -d $name.
=cut

sub remove_suseconnect_product {
    my ($name, $version, $arch, $params) = @_;
    $version //= scc_version();
    $arch //= get_required_var('ARCH');
    $params //= '';
    script_retry("SUSEConnect $debug_flag -d -p $name/$version/$arch $params", retry => 5, delay => 60, timeout => 180);
}

=head2 cleanup_registration

    cleanup_registration();

Wrapper for SUSEConnect --cleanup. Resets proxy SCC url if job has SCC_URL
variable set.
=cut

sub cleanup_registration {
    # Remove registration from the system
    assert_script_run "SUSEConnect $debug_flag --cleanup";
    # Define proxy SCC if provided
    my $proxyscc = get_var('SCC_URL');
    assert_script_run "echo \"url: $proxyscc\" > /etc/SUSEConnect" if $proxyscc;
}

=head2 register_product

    register_product();

Wrapper for SUSEConnect -r <regcode>. Requires SCC_REGCODE variable.
SUSEConnect --url with SMT/RMT server.
=cut

sub register_product {
    if (get_var('SMT_URL')) {
        assert_script_run("SUSEConnect  $debug_flag --url " . get_var('SMT_URL') . ' ' . uc(get_var('SLE_PRODUCT')) . '/' . scc_version(get_var('HDDVERSION')) . '/' . get_var('ARCH'), 200);
    } else {
        my $scc_reg_code = is_sles4sap ? get_required_var('SCC_REGCODE_SLES4SAP') : get_required_var('SCC_REGCODE');
        assert_script_run("SUSEConnect  $debug_flag -r " . $scc_reg_code, 200);
    }
}

sub register_addons_cmd {
    my ($addonlist, $retry) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    $retry //= 0;    # Don't retry by default
    my @addons = grep { defined $_ && $_ } split(/,/, $addonlist);
    if (check_var('DESKTOP', 'gnome') && is_sle('15+')) {
        my $desk = "sle-module-desktop-applications";
        record_info($desk, "Register $desk");
        add_suseconnect_product($desk, undef, undef, undef, 300, $retry);
    }
    foreach my $addon (@addons) {
        my $name = get_addon_fullname($addon);
        if (length $name) {
            record_info($name, "Register $name");
            if (grep(/$name/, @SLE12_MODULES) and is_sle('<15')) {
                my @ver = split(/\./, scc_version());
                add_suseconnect_product($name, $ver[0], undef, undef, 300, $retry);
            }
            elsif (grep(/$name/, keys %ADDONS_REGCODE)) {
                my $opt = "";
                if (is_sle("=15-SP4") && !is_jeos) {
                    $opt = " --auto-agree-with-licenses";
                }
                add_suseconnect_product($name, undef, undef, "-r " . $ADDONS_REGCODE{$name} . $opt, 300, $retry);
                if ($name =~ /we/) {
                    zypper_call("--gpg-auto-import-keys ref");
                    add_suseconnect_product($name, undef, undef, "-r " . $ADDONS_REGCODE{$name}, 300, $retry);
                }
            }
            else {
                add_suseconnect_product($name, undef, undef, undef, 300, $retry);
            }
        }
    }
}

sub deregister_addons_cmd {
    my ($addonlist) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    my @addons = grep { defined $_ && $_ } split(/,/, $addonlist);

    foreach my $addon (@addons) {
        my $name = get_addon_fullname($addon);
        if (length $name) {
            record_info($name, "Deregister $name");
            my $version = scc_version();
            my $arch = get_required_var('ARCH');

            # Special handling for SLE12 modules: use major version
            if (grep { $name eq $_ } @SLE12_MODULES and is_sle('<15')) {
                my @ver = split(/\./, $version);
                $version = $ver[0];
            }

            remove_suseconnect_product($name, $version, undef);
        }
    }
}

sub register_addons {
    my (@scc_addons) = @_;

    my ($regcodes_entered, $uc_addon);
    for my $addon (@scc_addons) {
        # no need to input registration code if register via SMT
        last if (get_var('SMT_URL'));
        # change to uppercase to match variable
        $uc_addon = uc $addon;
        my @addons_with_code = qw(geo live rt ltss ltss_es ltss_td ses espos);
        # WE doesn't need code on SLED
        push @addons_with_code, 'we' unless (check_var('SLE_PRODUCT', 'sled'));
        # HA doesn't need code on SLES4SAP or in migrations to 12-SP5
        push @addons_with_code, 'ha' unless (check_var('SLE_PRODUCT', 'sles4sap') || (is_sle('12-sp5+') && get_var('UPGRADE') && !get_var('IN_PATCH_SLE')));
        if ($addon eq 'we' && get_var('BETA_WE')) {
            accept_license;
            send_key $cmd{next};
        }
        if ((my $regcode = get_var("SCC_REGCODE_$uc_addon")) or ($addon eq "ltss")) {
            # skip addons which doesn't need to input scc code
            next unless grep { $addon eq $_ } @addons_with_code;
            if (check_var('VIDEOMODE', 'text')) {
                send_key_until_needlematch("scc-code-field-$addon", 'tab', 61, 3);
            }
            else {
                assert_and_click("scc-code-field-$addon", timeout => 240);
            }
            # avoid duplicated tests to manage LTSS regcode by integrating new variables
            $regcode = get_ltss_regcode($regcode) if $addon eq "ltss";
            type_string $regcode;
            save_screenshot;
            $regcodes_entered++;
        }
    }

    return $regcodes_entered;
}

sub get_ltss_regcode {
    my $regcode = shift;
    if (my $os_version = get_var("HDDVERSION")) {
        $os_version =~ s/-/_/g;
        return get_var("SCC_REGCODE_LTSS_$os_version", $regcode);
    }
    elsif ($os_version = get_var("VERSION_TO_INSTALL")) {
        # Check if VERSION_TO_INSTALL contains "12" or "15"
        return get_var("SCC_REGCODE_LTSS_12", $regcode) if $os_version =~ /12/;
        return get_var("SCC_REGCODE_LTSS_15", $regcode) if $os_version =~ /15/;
    }
    return $regcode;
}

sub assert_registration_screen_present {
    if (!get_var("HDD_SCC_REGISTERED")) {
        assert_screen_with_soft_timeout(
            'scc-registration',
            timeout => 350,
            soft_timeout => 300,
            bugref => 'bsc#1028774'
        );
    }
}

sub verify_preselected_modules {
    my $modules_needle = shift;

    return if check_screen($modules_needle, 30);    # pre-selected modules visible without scrolling
    my @modules = ('basesystem', 'server', split(/,/, get_var('ADDONS', '')));
    my @needles = map { 'addon-' . $_ } @modules;
    for (1 .. ADDONS_COUNT) {
        check_screen \@needles, 0;
        for my $needle (@needles) {
            @needles = grep { $_ ne $needle } @needles if match_has_tag($needle);
        }
        last if (!@needles || check_screen('scrolled-to-bottom', 0));
        send_key('down');
    }
    die 'Scroll reached to bottom not finding individual needles for each module.' if @needles;
}

sub _yast_scc_addons_handler {
    if (match_has_tag('yast_scc-license-dialog')) {
        send_key 'alt-a';
        next;
    }
    # yast may pop up dependencies or reboot prompt window
    if (match_has_tag('yast_scc-automatic-changes') or match_has_tag('unsupported-packages') or match_has_tag('yast_scc-prompt-reboot')) {
        wait_screen_change { send_key "alt-o" };
        next;
    }
    if (match_has_tag('yast_scc-installation-summary')) {
        send_key 'alt-f';
        last;
    }
}

sub skip_package_hub_if_necessary {
    my ($addon) = @_;
    my $skip_package_hub = 0;
    if (is_sle('15-SP2+') && $addon eq 'phub') {
        if (check_var('FLAVOR', 'Online')) {
            record_info('Skip phub', 'For Online medium we need to skip Package Hub registration due to
                after registering this module, some packages not supported that comes from openSUSE
                might conflict not allowing to have a predictable result - bsc#1172074');
            $skip_package_hub = 1;
        } elsif (check_var('FLAVOR', 'Full')) {
            record_info('Skip phub', 'Skipping Package Hub for Full medium due to it is an Online product - bsc#1157659');
            $skip_package_hub = 1;
        }
    }
    return $skip_package_hub;
}

sub process_scc_register_addons {
    # The value of SCC_ADDONS is a list of abbreviation of addons/modules
    # Following are abbreviations defined for modules and some addons
    #
    #  asmm - Advanced System Management Module
    # certm - Certifications Module
    # contm - Containers Module
    #   geo - Geo Clustering for SUSE Linux Enterprise High Availability
    #    ha - High Availability
    #  hpcm - HPC Module
    #   ids - IBM DLPAR sdk (ppc64le only)
    #   idu - IBM DLPAR Utils (ppc64le only)
    #   lgm - Legacy Module
    #  live - Live Patching
    #  ltss - Long Term Service Pack Support
    #   pcm - Public Cloud Module
    #  phub - PackageHub
    #   sdk - Software Development Kit
    #   ses - SUSE Enterprise Storage
    #   tcm - Toolchain Module
    #   tsm - Transactional Server Module
    #    we - Workstation
    #   wsm - Web and Scripting Module
    # espos - Extended Service Pack Overlap Support
    # nvidia- NVIDIA Compute Module
    if (get_var('SCC_ADDONS')) {
        if (check_screen('scc-beta-filter-checkbox', 5)) {
            if (is_sle('12-SP3+') || is_sle_micro) {
                # Uncheck 'Hide Beta Versions'
                # The workaround with send_key_until_needlematch is added,
                # because on ppc64le the shortcut key does not reach VM sporadically.
                send_key_until_needlematch('scc-beta-filter-unchecked', 'alt-i', 4, 5);
            }
            else {
                send_key 'alt-f';    # uncheck 'Filter Out Beta Version'
            }
            assert_screen('scc-beta-filter-unchecked');
        }
        my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));
        # remove empty elements
        @scc_addons = grep { $_ ne '' } @scc_addons;
        # For HA LTSS_TO_LTSS_ES migration if the original version is 12-SP4 then it only has LTSS
        if ((grep { $_ == 'ltss_es' } @scc_addons) && get_var('LTSS_TO_LTSS_ES') && is_sle('=12-SP4')) {
            foreach my $addon (@scc_addons) {
                $addon =~ s/ltss_es/ltss/g;
            }
        }

        for my $addon (@scc_addons) {
            next if (skip_package_hub_if_necessary($addon));
            if (check_var('VIDEOMODE', 'text') || check_var('SCC_REGISTER', 'console')) {
                # The actions of selecting scc addons have been changed on SP2 or later in textmode
                # For online migration, we have to do registration on pre-created HDD, set a flag
                # to distinguish the sle version of HDD and perform addons selection based on it
                if (get_var('ONLINE_MIGRATION') || get_var('PATCH')) {
                    select_addons_in_textmode($addon, get_var('HDD_SP2ORLATER'));
                }
                else {
                    select_addons_in_textmode($addon, get_var('SP2ORLATER'));
                }
            }
            else {
                # go to the top of the list before looking for the addon
                send_key "home";
                # move the list of addons down until the current addon is found
                send_key_until_needlematch ["scc-module-$addon", "scc-module-$addon-selected"], "down", ADDONS_COUNT;
                if (match_has_tag("scc-module-$addon")) {
                    # checkmark the requested addon
                    assert_and_click "scc-module-$addon";
                }
                else {
                    record_info("Module preselected", "Module $addon is already selected and installed by default");
                }
            }
        }
        save_screenshot;
        # go back and forward, checked checkboxes have to remember state poo#17840
        if (check_var('SCC_REGISTER', 'yast')) {
            wait_screen_change { send_key 'alt-b' };
            assert_screen 'scc-registration-already-registered';
            wait_screen_change { send_key $cmd{next} };
            for my $addon (@scc_addons) {
                send_key_until_needlematch "scc-module-$addon-selected", "down", ADDONS_COUNT;
            }
        }
        if (is_ppc64le && is_qemu) { wait_still_screen 5; }
        wait_screen_change(sub { send_key $cmd{next} }, 30, similarity_level => 35);    # all addons selected
        wait_still_screen 2;
        # Process addons licenses
        accept_addons_license @scc_addons;
        # Process GPG keys
        my @gpg_key_needles = qw(import-untrusted-gpg-key);
        # Repo key expired bsc#1180619
        push @gpg_key_needles, 'expired-gpg-key' if is_sle('=15');
        while (check_screen([@gpg_key_needles], 60)) {
            handle_untrusted_gpg_key if match_has_tag('import-untrusted-gpg-key');
            if (match_has_tag('expired-gpg-key')) {
                record_soft_failure 'bsc#1180619';
                send_key 'alt-y';
            }
        }
        # Press next only if entered reg code for any addon
        if (register_addons @scc_addons) {
            assert_screen 'ext-modules-reg-codes';
            send_key $cmd{next};
            wait_still_screen 2;
        }
        # start addons/modules registration, it needs longer time if select multiple or all addons/modules
        my $counter = ADDONS_COUNT;
        my @needles = qw(import-untrusted-gpg-key nvidia-validation-failed yast_scc-pkgtoinstall yast-scc-emptypkg inst-addon contacting-registration-server refreshing-repository system-probing);

        # In SLE Micro, we don't need to continue with registering any additional module.
        return if is_sle_micro;
        if (is_sle('15-SP2+')) {
            # In SLE 15 SP2 multipath detection happens directly after registration, so using it to detect that all pop-up are processed
            push @needles, 'enable-multipath' if get_var('MULTIPATH');
            # Similarly for encrypted partitions activation
            push @needles, 'encrypted_volume_activation_prompt' if (get_var('ENCRYPT_ACTIVATE_EXISTING') || get_var('ENCRYPT_CANCEL_EXISTING'));
        }
        push @needles, 'sles4sap-product-installation-mode' if (is_sles4sap() && is_sle('<=12-SP5'));
        while ($counter--) {
            die 'Addon registration repeated too much. Check if SCC is down.' if ($counter eq 1);
            assert_screen([@needles], 90);
            if (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
                next;
            }
            elsif (match_has_tag('nvidia-validation-failed')) {
                # nvidia repos unreliable
                record_soft_failure 'bsc#1214234';
                wait_still_screen { send_key 'alt-o' };
                send_key 'alt-n';
                next;
            }
            elsif (match_has_tag('yast_scc-pkgtoinstall')) {
                # yast shows the software install dialog
                wait_screen_change { send_key 'alt-a' };
                while (
                    # install packages take time if select many extensions and modules
                    assert_screen(
                        ['yast_scc-license-dialog', 'yast_scc-automatic-changes', 'yast_scc-prompt-reboot', 'yast_scc-installation-summary'], 1800
                    ))
                {
                    _yast_scc_addons_handler();
                }
                last;
            }
            # yast would display empty pkg install screen if no addon selected on sle12 sp0
            # set check_screen timeout longer to ensure the screen checked in this case
            elsif (match_has_tag('yast-scc-emptypkg')) {
                if (check_screen('yast-scc-emptypkg', 5)) {
                    send_key 'alt-a';
                    last;    # Exit yast scc register, no package need be install
                }
            }    # detecting if need to wait as registration is still on-going
            elsif (match_has_tag('contacting-registration-server') ||
                match_has_tag('system-probing') ||
                match_has_tag('refreshing-repository')) {
                sleep 5;
                next;
            }
            elsif (match_has_tag('inst-addon') ||
                match_has_tag('enable-multipath') ||
                match_has_tag('encrypted_volume_activation_prompt')) {
                # it would show Add On Product screen if scc registration correctly during installation
                # it would show software install dialog if scc registration correctly by yast2 scc
                last;
            }
            elsif (match_has_tag('sles4sap-product-installation-mode')) {
                last;
            }
        }
    }
    else {
        wait_still_screen(2, 4);
        send_key $cmd{next};
        if (check_var('HDDVERSION', '12')) {
            assert_screen 'yast-scc-emptypkg';
            send_key 'alt-a';
        }
    }
}

sub show_development_versions {
    assert_screen('scc-beta-filter-checkbox');
    send_key('alt-i');
    assert_screen('scc-beta-filter-unchecked');
}

sub fill_in_registration_data {
    fill_in_reg_server() if (!get_var("HDD_SCC_REGISTERED"));
    return if handle_scc_popups();
    process_modules();
}

sub handle_scc_popups {
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my $counter = ADDONS_COUNT;
        my @tags
          = qw(local-registration-servers registration-online-repos import-untrusted-gpg-key nvidia-validation-failed module-selection contacting-registration-server refreshing-repository);
        if (get_var('SCC_URL') || get_var('SMT_URL')) {
            push @tags, 'untrusted-ca-cert';
        }
        # For s390 there is only one product therefore license is confirmed in the initial welcome dialog.
        my $only_one_license = !(is_sle('=15-SP5') && (is_s390x));
        # The SLE15-SP2 license page moved after registration.
        push @tags, 'license-agreement' if (!get_var('MEDIA_UPGRADE') && is_sle('15-SP2+') && $only_one_license);
        push @tags, 'license-agreement-accepted' if (!get_var('MEDIA_UPGRADE') && is_sle('15-SP2+') && $only_one_license);
        push @tags, 'remove-repository' if (!get_var('MEDIA_UPGRADE') && is_sle('15-SP2+'));
        push @tags, 'leap-to-sle-registrition-finished' if (is_leap_migration);
        # The "Extension and Module Selection" won't be shown during upgrade to sle15, refer to:
        # https://bugzilla.suse.com/show_bug.cgi?id=1070031#c11
        push @tags, 'inst-addon' if is_sle('15+') && is_upgrade;
        # Repo key expired bsc#1180619
        push @tags, 'expired-gpg-key' if is_sle('=15');
        while ($counter--) {
            die 'Registration repeated too much. Check if SCC is down.' if ($counter eq 1);
            if (is_sle('>=15-SP4')
                && (get_var('VIDEOMODE', '') !~ /text|ssh-x/)
                && (get_var("DESKTOP", '') !~ /textmode/)
                && (get_var('REMOTE_CONTROLLER', '') !~ /vnc/)
                && !(get_var('PUBLISH_HDD_1', '') || check_var('SLE_PRODUCT', 'hpc'))) {
                apply_workaround_poo124652(\@tags, timeout => 360);
            }
            assert_screen(\@tags, timeout => 360);
            if (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
                next;
            }
            elsif (match_has_tag('nvidia-validation-failed')) {
                # sometimes nvidia driver repos are unreliable
                record_soft_failure 'bsc#1214234';
                wait_still_screen { send_key 'alt-o' };
                send_key 'alt-n';
                next;
            }
            elsif (match_has_tag('contacting-registration-server')) {
                # sometimes SCC just takes its time - just continue looking after a while
                sleep 5;
                next;
            }
            elsif (match_has_tag('refreshing-repository')) {
                # it takes some time to refresh repos
                sleep 5;
                next;
            }
            elsif ((get_var('SCC_URL') || get_var('SMT_URL')) && match_has_tag("untrusted-ca-cert")) {
                record_soft_failure 'bsc#943966' if get_var('SCC_CERT');
                send_key 'alt-t';
                wait_still_screen 5;
                # the behavior here of smt registration on 12sp1 is a little different with
                # 12sp0 and 12sp2, normally registration would start automatically after
                # untrusted certification imported, but it would not on 12sp1, and we have to
                # send next manually to start registration.
                if (get_var('SMT_URL') && (check_var('VERSION', '12-SP1') || check_var('HDDVERSION', '12-SP1'))) {
                    wait_screen_change { send_key $cmd{next} };
                }
                @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
                next;
            }
            elsif (match_has_tag('registration-online-repos')) {
                wait_screen_change { send_key(get_var('DISABLE_SLE_UPDATES') ? 'alt-n' : 'alt-y') };
                # Remove tag from array not to match twice
                @tags = grep { $_ ne 'registration-online-repos' } @tags;
                last if is_sle_micro;    # SLE Micro does not ask about modules to select
                next;
            }
            elsif (match_has_tag('module-selection')) {
                last;
            }
            elsif (match_has_tag('inst-addon')) {
                return 1;
            }
            elsif (match_has_tag('expired-gpg-key')) {
                record_soft_failure 'bsc#1180619';
                send_key 'alt-y';
                next;
            }
            elsif (match_has_tag("license-agreement")) {
                send_key 'alt-a';
                assert_screen('license-agreement-accepted');
                send_key $cmd{next};
                next;
            }
            elsif (match_has_tag("remove-repository")) {
                wait_still_screen 10;
                send_key $cmd{next};
                wait_still_screen 10;
                next;
            }
            elsif (match_has_tag('leap-to-sle-registrition-finished')) {
                # leap to sle do not need to add any addons
                return 1;
            }
        }
    }
}

sub select_addons_in_textmode {
    my ($addon, $flag) = @_;
    if ($flag) {
        send_key_until_needlematch 'scc-module-area-selected', 'tab';
        send_key_until_needlematch ["scc-module-$addon", "scc-module-$addon-selected"], 'down', 31, 5;
        if (match_has_tag("scc-module-$addon")) {
            send_key 'spc';
            # After selected/deselected an addon, yast scc would automatically
            # bounce the focus back to the top of list on SP2 or later in
            # textmode. Give a tiny time to wait it back completely to the top
            # of list.
            wait_still_screen 1;
        }
        else {
            record_info("Module preselected", "Module $addon is already selected and installed by default");
            # As we are not selecting this, scc will not bounce the focus,
            # hence we need to go up manually.
            for (1 .. 22) {
                send_key 'up';
            }
        }
    }
    else {
        send_key_until_needlematch "scc-module-$addon", 'tab';
        send_key "spc";
    }
}

sub registration_bootloader_cmdline {
    # https://www.suse.com/documentation/smt11/book_yep/data/smt_client_parameters.html
    # SCC_URL=https://smt.example.com
    # prevent rogue RMT servers to show up in unexpected selection dialogs
    # https://progress.opensuse.org/issues/94696
    set_var('SCC_URL', 'https://scc.suse.com') unless get_var('SCC_URL');
    my $cmdline = '';
    if (my $url = get_var('SMT_URL') || get_var('SCC_URL')) {
        $cmdline .= is_agama ? " inst.register_url=$url" : " regurl=$url";
        $cmdline .= " regcert=$url" if get_var('SCC_CERT');
    }
    return $cmdline;
}

sub registration_bootloader_params {
    my ($max_interval) = @_;    # see 'type_string'
    $max_interval //= 13;
    my @params;
    if (!(is_agama && check_var('FLAVOR', 'Full'))) {
        push @params, split ' ', registration_bootloader_cmdline;
    }
    type_string "@params", $max_interval;
    save_screenshot;
    return @params;
}

sub yast_scc_registration {
    my (%args) = @_;
    # For leap to sle migration, we need to install yast2-registration and rollback-helper
    # and start/enable rollback.service before running yast2 registration module.
    my $client_module = 'scc';
    if (is_leap_migration) {
        zypper_call('in yast2-migration-sle rollback-helper');
        systemctl("enable rollback");
        systemctl("start rollback");
        $client_module = 'registration';
    }
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => $client_module, yast2_opts => $args{yast2_opts});
    # For Aarch64 if the worker run with heavy loads, it will
    # timeout in nearly 120 seconds. So we set it to 150. Same
    # for s390 since timeout happen.
    assert_screen('scc-registration', timeout => (is_aarch64 || is_s390x) ? 150 : 120,);
    fill_in_registration_data;
    wait_serial("$module_name-0", 150) || die "yast scc failed";
    # To check repos validity after registration, call 'validate_repos' as needed
}

sub skip_registration {
    wait_screen_change { send_key "alt-s" };    # skip SCC registration
    assert_screen([qw(scc-skip-reg-warning-yes scc-skip-reg-warning-ok scc-skip-reg-no-warning)]);
    if (match_has_tag('scc-skip-reg-warning-ok')) {
        send_key "alt-o";    # confirmed skip SCC registration
        wait_still_screen;
        send_key $cmd{next};
    }
    elsif (match_has_tag('scc-skip-reg-warning-yes')) {
        send_key "alt-y";    # confirmed skip SCC registration
        wait_still_screen;
        send_key $cmd{next};
    }
}

sub get_addon_fullname {
    my ($addon) = @_;

    # extensions product list
    my %product_list = (
        ha => 'sle-ha',
        geo => 'sle-ha-geo',
        we => 'sle-we',
        sdk => is_sle('15+') ? 'sle-module-development-tools' : 'sle-sdk',
        dev => 'sle-module-development-tools',
        ses => 'ses',
        live => is_sle('15+') ? 'sle-module-live-patching' : 'sle-live-patching',
        asmm => is_sle('15+') ? 'sle-module-basesystem' : 'sle-module-adv-systems-management',
        base => 'sle-module-basesystem',
        contm => 'sle-module-containers',
        desktop => 'sle-module-desktop-applications',
        hpcm => 'sle-module-hpc',
        legacy => 'sle-module-legacy',
        lgm => 'sle-module-legacy',
        ltss => is_hpc('15+') ? 'SLE_HPC-LTSS' : 'SLES-LTSS',
        ltss_es => 'SLES-LTSS-Extended-Security',
        ltss_td => 'SLES-LTSS-TERADATA',
        pcm => 'sle-module-public-cloud',
        rt => 'SUSE-Linux-Enterprise-RT',
        sapapp => 'sle-module-sap-applications',
        script => 'sle-module-web-scripting',
        wsm => 'sle-module-web-scripting',
        serverapp => 'sle-module-server-applications',
        tcm => is_sle('15+') ? 'sle-module-development-tools' : 'sle-module-toolchain',
        python2 => 'sle-module-python2',
        python3 => 'sle-module-python3',
        phub => 'PackageHub',
        tsm => 'sle-module-transactional-server',
        espos => 'ESPOS',
        nvidia => 'sle-module-NVIDIA-compute',
        idu => is_sle('15+') ? 'IBM-POWER-Tools' : 'IBM-DLPAR-utils',
        ids => is_sle('15+') ? 'IBM-POWER-Adv-Toolchain' : 'IBM-DLPAR-SDK',
    );
    return $product_list{"$addon"};
}


sub fill_in_reg_server {
    # Set product specific SCC_REGCODE if it was provided. Defaults to SCC_REGCODE if set
    my $regcode = get_var('SCC_REGCODE', '');
    if (get_var('SLE_PRODUCT')) {
        my $prdcode = get_var('SCC_REGCODE_' . uc(get_var('SLE_PRODUCT')), '');
        $regcode = $prdcode if ($prdcode);
    }

    # rmt slp discovery, the smt server address will auto filled
    # and selected. We do this kind of test on local openQA to avoid
    # affecting the jobs on openqa.suse.de.
    if (get_var('SLP_RMT_INSTALL')) {
        wait_screen_change { send_key $cmd{next} };
        return;
    }
    if (!get_var("SMT_URL")) {
        if (is_sle('15+') && check_var('DESKTOP', 'textmode')) {
            send_key "alt-m";    # select email field if yast2 add-on
        }
        else {
            send_key "alt-e";    # select email field if installation
        }
        send_key "backspace";    # delete m or e
        type_string get_var('SCC_EMAIL') if get_var('SCC_EMAIL');
        save_screenshot;
        send_key "alt-c";
        type_string $regcode if ($regcode);
    }
    else {
        send_key "alt-i";
        # Fresh install sles12sp2/3/4/5 shortcut is different with upgrade version.
        # We add a workaround for bug bsc#1141962, which was caused by different shortcuts for
        # patch_sle and scc_register for local smt scenario. So we add IN_PATCH_SLE check for this.
        send_key "alt-l" if is_sle('>=15');
        if (is_sle('12-sp2+') && is_sle('<15') && (get_var('UPGRADE') || get_var('ONLINE_MIGRATION'))
            && check_var('IN_PATCH_SLE', '1')) {
            send_key "alt-l";
        }
        else {
            send_key "alt-o";
        }
        # Remove https://smt.example.com
        for (1 .. 30) { send_key 'backspace'; }
        type_string get_required_var("SMT_URL");
    }
    save_screenshot;
    wait_screen_change { send_key $cmd{next} };
}

# De-register the system from the SUSE Customer Center
sub scc_deregistration {
    my (%args) = @_;
    $args{version_variable} //= 'VERSION';
    if (is_sle('12-SP1+', get_var($args{version_variable}))) {
        # Need quit packagekit to ensure it won't block to de-register system via SUSEConnect.
        quit_packagekit;
        wait_for_purge_kernels;
        assert_script_run('SUSEConnect --version');
        # We don't need to pass $debug_flag to SUSEConnect, because it's already set
        my $deregister_ret = script_run("SUSEConnect --de-register --debug > /tmp/SUSEConnect.debug 2>&1", 300);
        if ($deregister_ret) {
            # See git blame for previous workarounds.
            upload_logs "/tmp/SUSEConnect.debug";
            die "SUSEConnect --de-register returned error code $deregister_ret";
        }
        my $output = script_output "SUSEConnect $debug_flag -s";
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
    else {
        assert_script_run("zypper removeservice `zypper services --show-enabled-only --sort-by-name | awk {'print\$5'} | sed -n '1,2!p'`");
        assert_script_run('rm /etc/zypp/credentials.d/* /etc/SUSEConnect');
        my $output = script_output "SUSEConnect $debug_flag -s";
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
}

# Some sle product addons name should be changed for sle15
# 1, Some extensions / modules are changed since sle15:
# Advanced Systems Management: packages are moved to SLE 15 base system
# SLE-HA-GEO extension is merged to SLE-HA extension
# SDK extension becomes Development-Tools module since sle15
# Toolchain module: packages are moved to Development module
# 2, Different addon names used between yast_scc_registration and
# %SLE15_MODULES, such as:
# lgm -- legacy
# wsm -- script
# Not good idea to use different module names, we have to bridge the
# gap here to use existing needles
sub rename_scc_addons {
    return unless get_var('SCC_ADDONS') && is_sle('15+');

    my %addons_map = (
        asmm => 'base',
        geo => 'ha',
        tcm => 'sdk',
        lgm => 'legacy',
        wsm => 'script',
    );
    my @addons_new = ();

    for my $i (split(/,/, get_var('SCC_ADDONS'))) {
        push @addons_new, defined $addons_map{$i} ? $addons_map{$i} : $i;
    }
    set_var('SCC_ADDONS', join(',', @addons_new));
}

sub verify_scc {
    record_info('proxySCC/SCC', 'Verifying that proxySCC and SCC can be accessed');
    assert_script_run("curl ${\(get_var('SCC_URL'))}/login") if get_var('SCC_URL');
    assert_script_run("curl https://scc.suse.com/login");
}

sub investigate_log_empty_license {
    my $filter_products = "grep -Po '<SUSE::Connect::Remote::Product.*?(extensions|isbase=(true|false)>)'";
    my $y2log_file = '/var/log/YaST2/y2log';
    my $filter_empty_eula = qq[grep '.*eula_url="".*'];
    my $orderuniquebyid = 'sort -u -t, -k1,1';
    my $command = "$filter_products $y2log_file | $filter_empty_eula | $orderuniquebyid";
    my @products = split(/\n/, script_output($command));
    my %fields = (
        id => qr/(?<id>(?<=id=)\d+)/,
        friendly_name => qr/(?<friendly_name>(?<=friendly_name=").*?(?="))/
    );
    my $message;
    for my $product (@products) {
        if ($product =~ /$fields{id}.*?$fields{friendly_name}.*?$fields{asset_url}/) {
            $message .= "$+{friendly_name}: https://scc.suse.com/admin/products/$+{id}\n";
        }
    }
    if ($message) {
        record_info(
            'Empty eula_url',
            "Empty EULA was found in YaST logs (eula_url=\"\") for the following products:\n" .
              "$message\n" .
              "Please, file Bugzilla ticket agains SCC if license is not properly set.\n" .
              "In case of licence available, check if the asset for the license has been properly synchronized\n" .
              "by taking a look in http://openqa.suse.de/assets/repo/ for the corresponding product/build\n" .
              "and searching for a path ending in \'.license/license.txt\' .Otherwise, please file a Progress ticket.");
    }
}

sub process_modules {
    # Process modules on sle 15
    if (is_sle '15+') {
        my $modules_needle = "modules-preselected-" . get_required_var('SLE_PRODUCT');
        # Check needle 'scc-beta-filter-checkbox', if yes means product still in BETA phase, then continue assert process;
        # if not means product already out of BETA phase, then do not need to assert the 'scc-beta-filter-checkbox' any more.

        # Assert multi tags scc-beta-filter-checkbox and scc-without-beta-filter-checkbox to ensure catch all conditions.
        assert_screen [qw(scc-beta-filter-checkbox scc-without-beta-filter-checkbox)];
        if (match_has_tag('scc-beta-filter-checkbox')) {
            if (check_var('BETA', '1')) {
                show_development_versions;
            }
            elsif (!check_screen($modules_needle, 0)) {
                record_info('bsc#1094457 : SLE 15 modules are still in BETA while product enter GMC phase');
                show_development_versions;
            }
        }

        verify_preselected_modules($modules_needle) if get_var('CHECK_PRESELECTED_MODULES');
        # Add desktop module for SLES if desktop is gnome
        # Need desktop application for minimalx to make change_desktop work
        if ((check_var('SLE_PRODUCT', 'sles') && !is_leap_migration)
            && (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'minimalx'))
            && (my $addons = get_var('SCC_ADDONS')) !~ /(?:desktop|we)/) {
            $addons = $addons ? $addons . ',desktop' : 'desktop';
            set_var('SCC_ADDONS', $addons);
        }
    }
    # Process modules
    if (check_var('SCC_REGISTER', 'installation') || check_var('SCC_REGISTER', 'yast') || check_var('SCC_REGISTER', 'console')) {
        process_scc_register_addons;
    }
    elsif (!get_var('SCC_REGISTER', '') =~ /addon|network/) {
        send_key $cmd{next};
    }
}

sub runtime_registration {
    return if get_var('HDD_SCC_REGISTERED');
    my $cmd = ' -r ' . get_required_var 'SCC_REGCODE';
    my $scc_addons = get_var 'SCC_ADDONS', '';
    # fake scc url pointing to synced repos on openQA
    # valid only for products currently in development
    # please unset in job def *SCC_URL* if not required
    my $fake_scc = get_var 'SCC_URL', '';
    $cmd .= ' --url ' . $fake_scc if $fake_scc;
    my $retries = 5;    # number of retries to run SUSEConnect commands
    my $delay = 60;    # time between retries to run SUSEConnect commands


    select_serial_terminal;
    die 'SUSEConnect package is not pre-installed!' if script_run 'command -v SUSEConnect';
    if ((is_jeos || is_sle_micro)) {
        my $status = script_output('SUSEConnect --status-text');
        die 'System has been already registered!' if ($status !~ m/not registered/i);
    }

    # There are sporadic failures due to the command timing out, so we increase the timeout
    # and make use of retries to overcome a possible sporadic network issue.
    # script_output_retry is useless for `transactional-update` cmd because it returns 0 even with failure
    # trup_call will raise a failure if the command fails
    if (is_transactional) {
        trup_call('register' . $cmd);
        trup_call('--continue run zypper --gpg-auto-import-keys refresh') if is_staging;
        if (is_sle_micro('>=6.0') && is_sle_micro('<=6.1')) {
            process_reboot(trigger => 1);
            add_suseconnect_product('SL-Micro-Extras', get_var('HDDVERSION'), undef, undef, 90, 1);
        }
        process_reboot(trigger => 1);
    }
    else {
        my $output = script_output_retry("SUSEConnect $cmd", retry => $retries, delay => $delay, timeout => 180);
        die($output) if ($output =~ m/error|timeout|problem retrieving/i);
    }
    # Check available extenstions (only present in sle)
    my $extensions = script_output_retry("SUSEConnect --list-extensions", retry => $retries, delay => $delay, timeout => 180);
    record_info('Extensions', $extensions);

    die("None of the modules are Activated") if ($extensions !~ m/Activated/ && is_sle);

    # add modules
    register_addons_cmd($scc_addons, $retries) if $scc_addons;
    # Check that repos actually work
    zypper_call 'refresh';
    zypper_call 'repos --details';
}

1;
