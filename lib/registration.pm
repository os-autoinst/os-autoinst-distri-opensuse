# Copyright (C) 2015-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package registration;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils qw(addon_decline_license assert_screen_with_soft_timeout zypper_call systemctl handle_untrusted_gpg_key);
use version_utils qw(is_sle is_caasp is_upgrade);
use constant ADDONS_COUNT => 50;
use y2_module_consoletest;

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
  scc_deregistration
  scc_version
  get_addon_fullname
  rename_scc_addons
  is_module
  install_docker_when_needed
  verify_scc
  investigate_log_empty_license
  register_addons_cmd
  %SLE15_MODULES
  %SLE15_DEFAULT_MODULES
  @SLE15_ADDONS_WITHOUT_LICENSE
);

# We already have needles with names which are different we would use here
# As it's only workaround, better not to create another set of needles.
# Add python2 module, refer to https://jira.suse.de/browse/SLE-3167
our %SLE15_MODULES = (
    base      => 'Basesystem',
    sdk       => 'Development-Tools',
    desktop   => 'Desktop-Applications',
    legacy    => 'Legacy',
    script    => 'Web-Scripting',
    serverapp => 'Server-Applications',
    contm     => 'Containers',
    pcm       => 'Public-Cloud',
    sapapp    => 'SAP-Applications',
    python2   => 'Python2',
);

# The expected modules of a default installation per product. Use them if they
# are not preselected, to crosscheck or just recreate automatic selections
# manually
our %SLE15_DEFAULT_MODULES = (
    sles     => 'base,serverapp',
    sled     => 'base,desktop',
    sles4sap => 'base,desktop,serverapp,ha,sapapp',
);

our @SLE15_ADDONS_WITHOUT_LICENSE        = qw(ha sdk wsm we hpcm live);
our @SLE15_ADDONS_WITH_LICENSE_NOINSTALL = qw(ha we);

# Method to determine if a short name references a module based on what's defined
# on %SLE15_MODULES
sub is_module {
    my $name = shift;
    return defined $SLE15_MODULES{$name};
}

sub accept_addons_license {
    my (@scc_addons) = @_;

    # To check the current state of licenses in the product one can conduct
    # the following steps, e.g. for SLE15:
    #   isc co SUSE:SLE-15:GA 000product
    #   grep -l EULA SUSE:SLE-15:GA/000product/*.product | sed 's/.product//'
    # All shown products have a license that should be checked.
    my @addons_with_license = qw(geo rt idu ids);
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
    push @addons_with_license, @SLE15_ADDONS_WITHOUT_LICENSE unless is_sle('15+');
    # HA and WE have licenses when calling yast2 scc
    push @addons_with_license, @SLE15_ADDONS_WITH_LICENSE_NOINSTALL if (is_sle('15+') and get_var('IN_PATCH_SLE'));

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
    $arch    //= '${CPU}';
    $params  //= '';
    $retry   //= 0;                 # run SUSEConnect a 2nd time to workaround the gpg error due to missing repo key on 1st run

    my $result = script_run("SUSEConnect -p $name/$version/$arch $params", $timeout);
    if ($result != 0 && $retry) {
        if ($name =~ /PackageHub/) {
            record_soft_failure 'bsc#1124318 - Fail to get module repo metadata - running the command again as a workaround';
        }
        assert_script_run("SUSEConnect -p $name/$version/$arch $params", $timeout);
    }
}

=head2 remove_suseconnect_product

    remove_suseconnect_product($name, [$version, [$arch, [$params]]]);

Wrapper for SUSEConnect -d $name.
=cut
sub remove_suseconnect_product {
    my ($name, $version, $arch, $params) = @_;
    $version //= scc_version();
    $arch    //= get_required_var('ARCH');
    $params  //= '';
    assert_script_run("SUSEConnect -d -p $name/$version/$arch $params");
}

=head2 cleanup_registration

    cleanup_registration();

Wrapper for SUSEConnect --cleanup. Resets proxy SCC url if job has SCC_URL
variable set.
=cut
sub cleanup_registration {
    # Remove registration from the system
    assert_script_run 'SUSEConnect --clean';
    # Define proxy SCC if provided
    my $proxyscc = get_var('SCC_URL');
    assert_script_run "echo \"url: $proxyscc\" > /etc/SUSEConnect" if $proxyscc;
}

=head2 register_product

    register_product();

Wrapper for SUSEConnect -r <regcode>. Requires SCC_REGCODE variable.
=cut
sub register_product {
    assert_script_run 'SUSEConnect -r ' . get_required_var('SCC_REGCODE');
}

sub register_addons_cmd {
    my ($addonlist) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    my @addons = grep { defined $_ && $_ } split(/,/, $addonlist);
    foreach my $addon (@addons) {
        my $name = get_addon_fullname($addon);
        if ($name =~ /adv|containers|legacy|toolchain|web-scripting|public-cloud/) {
            my @ver = split(/\./, scc_version());
            add_suseconnect_product($name, $ver[0]);
        }
        elsif ($name =~ /live/) {
            add_suseconnect_product($name, undef, undef, "-r " . get_var('SCC_REGCODE_LIVE'));
        }
        elsif ($name =~ /we/) {
            add_suseconnect_product($name, undef, undef, "-r " . get_var('SCC_REGCODE_WE'));
        }
        elsif ($name =~ /LTSS/) {
            add_suseconnect_product($name, undef, undef, "-r " . get_var('SCC_REGCODE_LTSS'));
        }
        elsif ($name =~ /sdk/) {
            add_suseconnect_product($name);
        }
        else {
            next;
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
        my @addons_with_code = qw(geo live rt ltss ses);
        # WE doesn't need code on SLED
        push @addons_with_code, 'we' unless (check_var('SLE_PRODUCT', 'sled'));
        # HA doesn't need code on SLES4SAP
        push @addons_with_code, 'ha' unless (check_var('SLE_PRODUCT', 'sles4sap'));
        if ((my $regcode = get_var("SCC_REGCODE_$uc_addon")) or ($addon eq "ltss")) {
            # skip addons which doesn't need to input scc code
            next unless grep { $addon eq $_ } @addons_with_code;
            if (check_var('VIDEOMODE', 'text')) {
                send_key_until_needlematch "scc-code-field-$addon", 'tab';
            }
            else {
                assert_and_click("scc-code-field-$addon", timeout => 240);
            }
            # avoid duplicated tests to manage LTSS regcode by integrating new variables
            if ($addon eq "ltss") {
                my $os_sp_version = get_var("HDDVERSION");
                $os_sp_version =~ s/-/_/g;
                $regcode = get_var("SCC_REGCODE_LTSS_$os_sp_version", $regcode);
            }
            type_string $regcode;
            save_screenshot;
            $regcodes_entered++;
        }
    }

    return $regcodes_entered;
}

sub assert_registration_screen_present {
    if (!get_var("HDD_SCC_REGISTERED")) {
        assert_screen_with_soft_timeout(
            'scc-registration',
            timeout      => 350,
            soft_timeout => 300,
            bugref       => 'bsc#1028774'
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
    if (get_var('SCC_ADDONS')) {
        if (check_screen('scc-beta-filter-checkbox', 5)) {
            if (get_var('SP3ORLATER')) {
                send_key 'alt-i';    # uncheck 'Hide Beta Versions'
            }
            else {
                send_key 'alt-f';    # uncheck 'Filter Out Beta Version'
            }
            assert_screen('scc-beta-filter-unchecked');
        }
        my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));
        # remove empty elements
        @scc_addons = grep { $_ ne '' } @scc_addons;

        for my $addon (@scc_addons) {
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
        wait_screen_change { send_key $cmd{next} };    # all addons selected
        wait_still_screen 2;
        # Process addons licenses
        accept_addons_license @scc_addons;
        # Press next only if entered reg code for any addon
        if (register_addons @scc_addons) {
            assert_screen 'ext-modules-reg-codes';
            send_key $cmd{next};
            wait_still_screen 2;
        }
        # start addons/modules registration, it needs longer time if select multiple or all addons/modules
        my $counter = ADDONS_COUNT;
        while ($counter--) {
            die 'Addon registration repeated too much. Check if SCC is down.' if ($counter eq 1);
            assert_screen [
                qw(import-untrusted-gpg-key yast_scc-pkgtoinstall yast-scc-emptypkg inst-addon contacting-registration-server refreshing-repository)];
            if (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
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
                else {
                    record_soft_failure 'bsc#1040758';
                    next;    # Yast may popup dependencies or software install dialog, enter determine statement again.
                }
            }
            elsif (match_has_tag('contacting-registration-server')) {
                sleep 5;
                next;
            }
            elsif (match_has_tag('refreshing-repository')) {
                sleep 5;
                next;
            }
            elsif (match_has_tag('inst-addon')) {
                # it would show Add On Product screen if scc registration correctly during installation
                # it would show software install dialog if scc registration correctly by yast2 scc
                last;
            }
        }
    }
    else {
        send_key $cmd{next};
        if (check_var('HDDVERSION', '12')) {
            assert_screen 'yast-scc-emptypkg';
            send_key 'alt-a';
        }
    }
}

sub process_scc_register {
    if (check_var('SCC_REGISTER', 'installation') || check_var('SCC_REGISTER', 'yast') || check_var('SCC_REGISTER', 'console')) {
        process_scc_register_addons;
    }
    elsif (!get_var('SCC_REGISTER', '') =~ /addon|network/) {
        send_key $cmd{next};
    }
}

sub show_development_versions {
    assert_screen('scc-beta-filter-checkbox');
    send_key('alt-i');
    assert_screen('scc-beta-filter-unchecked');
}

sub fill_in_registration_data {
    my ($addon, $uc_addon);
    fill_in_reg_server() if (!get_var("HDD_SCC_REGISTERED"));

    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my $counter = ADDONS_COUNT;
        my @tags
          = qw(local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection contacting-registration-server refreshing-repository);
        if (get_var('SCC_URL') || get_var('SMT_URL')) {
            push @tags, 'untrusted-ca-cert';
        }
        # The "Extension and Module Selection" won't be shown during upgrade to sle15, refer to:
        # https://bugzilla.suse.com/show_bug.cgi?id=1070031#c11
        push @tags, 'inst-addon' if is_sle('15+') && is_upgrade;
        while ($counter--) {
            die 'Registration repeated too much. Check if SCC is down.' if ($counter eq 1);
            assert_screen(\@tags, 60);
            if (match_has_tag('import-untrusted-gpg-key')) {
                handle_untrusted_gpg_key;
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
                next;
            }
            elsif (match_has_tag('module-selection')) {
                last;
            }
            elsif (match_has_tag('inst-addon')) {
                return;
            }
        }
    }

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
        if (check_var('SLE_PRODUCT', 'sles')
            && (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'minimalx'))
            && (my $addons = get_var('SCC_ADDONS')) !~ /(?:desktop|we)/)
        {
            $addons = $addons ? $addons . ',desktop' : 'desktop';
            set_var('SCC_ADDONS', $addons);
        }
    }

    process_scc_register;
}

sub select_addons_in_textmode {
    my ($addon, $flag) = @_;
    if ($flag) {
        send_key_until_needlematch 'scc-module-area-selected', 'tab';
        send_key_until_needlematch ["scc-module-$addon", "scc-module-$addon-selected"], 'down', 30, 5;
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
            for (1 .. 15) {
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
    if (my $url = get_var('SMT_URL') || get_var('SCC_URL')) {
        my $cmdline = " regurl=$url";
        $cmdline .= " regcert=$url" if get_var('SCC_CERT');
        return $cmdline;
    }
}

sub registration_bootloader_params {
    my ($max_interval) = @_;    # see 'type_string'
    $max_interval //= 13;
    my @params;
    push @params, split ' ', registration_bootloader_cmdline;
    type_string "@params", $max_interval;
    save_screenshot;
    return @params;
}

sub yast_scc_registration {
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'scc');
    assert_screen_with_soft_timeout(
        'scc-registration',
        timeout      => 90,
        soft_timeout => 30,
        bugref       => 'wait longer time to start yast2 scc in case of multiple jobs start to execute it in parallel on a same worker'
    );

    fill_in_registration_data;
    wait_serial("$module_name-0", 150) || die "yast scc failed";
    # To check repos validity after registration, call 'validate_repos' as needed
}

sub skip_registration {
    wait_screen_change { send_key "alt-s" };    # skip SCC registration
    assert_screen([qw(scc-skip-reg-warning-yes scc-skip-reg-warning-ok scc-skip-reg-no-warning)]);
    if (match_has_tag('scc-skip-reg-warning-ok')) {
        send_key "alt-o";                       # confirmed skip SCC registration
        wait_still_screen;
        send_key $cmd{next};
    }
    elsif (match_has_tag('scc-skip-reg-warning-yes')) {
        send_key "alt-y";                       # confirmed skip SCC registration
    }
}

sub get_addon_fullname {
    my ($addon) = @_;

    # extensions product list
    my %product_list = (
        ha        => 'sle-ha',
        geo       => 'sle-ha-geo',
        we        => 'sle-we',
        sdk       => is_sle('15+') ? 'sle-module-development-tools' : 'sle-sdk',
        ses       => 'ses',
        live      => is_sle('15+') ? 'sle-module-live-patching' : 'sle-live-patching',
        asmm      => 'sle-module-adv-systems-management',
        base      => 'sle-module-basesystem',
        contm     => 'sle-module-containers',
        desktop   => 'sle-module-desktop-applications',
        hpcm      => 'sle-module-hpc',
        legacy    => 'sle-module-legacy',
        lgm       => 'sle-module-legacy',
        ltss      => 'SLES-LTSS',
        pcm       => 'sle-module-public-cloud',
        rt        => 'SUSE-Linux-Enterprise-RT',
        script    => 'sle-module-web-scripting',
        serverapp => 'sle-module-server-applications',
        tcm       => 'sle-module-toolchain',
        wsm       => 'sle-module-web-scripting',
        python2   => 'sle-module-python2',
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
        # Fresh install sles12sp2/3/4/5 shortcut is different with upgrade version
        if ((is_sle('12-sp2+') && is_sle('<15') && (get_var('UPGRADE') || get_var('ONLINE_MIGRATION'))) || is_sle('>=15')) {
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
        assert_script_run('SUSEConnect --version');
        my $deregister_ret = script_run('SUSEConnect --de-register --debug > /tmp/SUSEConnect.debug 2>&1', 200);
        if (defined $deregister_ret and $deregister_ret == 104) {
            # https://bugzilla.suse.com/show_bug.cgi?id=1119512
            # https://bugzilla.suse.com/show_bug.cgi?id=1122497
            record_soft_failure 'bsc#1119512 and bsc#1122497';
            # Workaround the soft-failure
            assert_script_run('SUSEConnect --cleanup', 200);
        }
        # If there was a failure de-registering, upload debug information for the SCC team
        upload_logs "/tmp/SUSEConnect.debug" if (defined $deregister_ret and $deregister_ret);
        my $output = script_output 'SUSEConnect -s';
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
    else {
        assert_script_run("zypper removeservice `zypper services --show-enabled-only --sort-by-name | awk {'print\$5'} | sed -n '1,2!p'`");
        assert_script_run('rm /etc/zypp/credentials.d/* /etc/SUSEConnect');
        my $output = script_output 'SUSEConnect -s';
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
        geo  => 'ha',
        tcm  => 'sdk',
        lgm  => 'legacy',
        wsm  => 'script',
    );
    my @addons_new = ();

    for my $i (split(/,/, get_var('SCC_ADDONS'))) {
        push @addons_new, defined $addons_map{$i} ? $addons_map{$i} : $i;
    }
    set_var('SCC_ADDONS', join(',', @addons_new));
}

sub install_docker_when_needed {
    if (is_caasp) {
        # Docker should be pre-installed in MicroOS
        die 'Docker is not pre-installed.' if zypper_call('se -x --provides -i docker');
    }
    else {
        if (is_sle('<15')) {
            assert_script_run('zypper se docker || zypper -n ar -f http://download.suse.de/ibs/SUSE:/SLE-12:/Update/standard/SUSE:SLE-12:Update.repo');
        }
        elsif (is_sle) {
            add_suseconnect_product('sle-module-containers');
        }
        # docker package can be installed
        zypper_call('in docker');
    }

    # docker daemon can be started
    systemctl('start docker');
    systemctl('status docker');
    assert_script_run('docker info');
}

sub verify_scc {
    record_info('proxySCC/SCC', 'Verifying that proxySCC and SCC can be accessed');
    assert_script_run("curl ${\(get_var('SCC_URL'))}/login") if get_var('SCC_URL');
    assert_script_run("curl https://scc.suse.com/login");
}

sub investigate_log_empty_license {
    my $filter_products   = "grep -Po '<SUSE::Connect::Remote::Product.*?(extensions|isbase=(true|false)>)'";
    my $y2log_file        = '/var/log/YaST2/y2log';
    my $filter_empty_eula = qq[grep '.*eula_url="".*'];
    my $orderuniquebyid   = 'sort -u -t, -k1,1';
    my $command           = "$filter_products $y2log_file | $filter_empty_eula | $orderuniquebyid";
    my @products          = split(/\n/, script_output($command));
    my %fields            = (
        id            => qr/(?<id>(?<=id=)\d+)/,
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

1;
