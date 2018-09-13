# Copyright (C) 2015-2016 SUSE LLC
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

use testapi;
use utils qw(addon_decline_license assert_screen_with_soft_timeout zypper_call systemctl);
use version_utils qw(is_sle is_caasp sle_version_at_least is_sle12_hdd_in_upgrade);

our @EXPORT = qw(
  add_suseconnect_product
  remove_suseconnect_product
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
  %SLE15_MODULES
  %SLE15_DEFAULT_MODULES
  @SLE15_ADDONS_WITHOUT_LICENSE
);

# We already have needles with names which are different we would use here
# As it's only workaround, better not to create another set of needles.
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
);

# The expected modules of a default installation per product. Use them if they
# are not preselected, to crosscheck or just recreate automatic selections
# manually
our %SLE15_DEFAULT_MODULES = (
    sles     => 'base,serverapp',
    sled     => 'base,desktop',
    sles4sap => 'base,desktop,serverapp,ha,sapapp',
);

our @SLE15_ADDONS_WITHOUT_LICENSE = qw(ha sdk wsm we hpcm);

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
    my @addons_with_license = qw(geo live rt idu ids lgm ses);

    # In SLE 15 some modules do not have license or have the same
    # license (see bsc#1089163) and so are not be shown twice
    push @addons_with_license, @SLE15_ADDONS_WITHOUT_LICENSE unless is_sle('15+');

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
    my ($name, $version, $arch, $params) = @_;
    $version //= scc_version();
    $arch    //= get_required_var('ARCH');
    $params  //= '';
    assert_script_run("SUSEConnect -p $name/$version/$arch $params");
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

sub register_addons {
    my (@scc_addons) = @_;

    my ($regcodes_entered, $uc_addon);
    for my $addon (@scc_addons) {
        # no need to input registration code if register via SMT
        last if (get_var('SMT_URL'));
        $uc_addon = uc $addon;    # change to uppercase to match variable
        if (my $regcode = get_var("SCC_REGCODE_$uc_addon")) {
            # skip addons which doesn't need to input scc code
            next unless grep { $addon eq $_ } qw(ha geo we live rt ltss ses);
            if (check_var('VIDEOMODE', 'text')) {
                send_key_until_needlematch "scc-code-field-$addon", 'tab';
            }
            else {
                assert_and_click "scc-code-field-$addon", 'left', 120;
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

sub fill_in_registration_data {
    my ($addon, $uc_addon);
    fill_in_reg_server() if (!get_var("HDD_SCC_REGISTERED"));

    my @known_untrusted_keys = qw(
      import-trusted-gpg-key-nvidia-F5113243C66B6EAE
      import-trusted-gpg-key-phub-9C214D4065176565
      import-untrusted-gpg-key-ids-key-A5665AC46976A827
      import-untrusted-gpg-key-idv-key-A5665AC46976A827
    );
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my $counter = 50;
        my @tags
          = qw(local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection contacting-registration-server refreshing-repository);
        if (get_var('SCC_URL') || get_var('SMT_URL')) {
            push @tags, 'untrusted-ca-cert';
        }
        # The "Extension and Module Selection" won't be shown during upgrade to sle15, refer to:
        # https://bugzilla.suse.com/show_bug.cgi?id=1070031#c11
        push @tags, 'inst-addon' if is_sle('15+') && is_sle12_hdd_in_upgrade;
        while ($counter--) {
            die 'Registration repeated too much. Check if SCC is down.' if ($counter eq 1);
            assert_screen(\@tags);
            if (match_has_tag("import-untrusted-gpg-key")) {
                if (check_var("IMPORT_UNTRUSTED_KEY", 1) || check_screen(\@known_untrusted_keys, 0)) {
                    wait_screen_change { send_key "alt-t" };    # import
                }
                else {
                    wait_screen_change { send_key "alt-c" };    # cancel
                }
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
        if (check_var('BETA', '1')) {
            assert_screen('scc-beta-filter-checkbox');
            send_key('alt-i');
        }
        elsif (!check_screen($modules_needle, 0)) {
            record_info('bsc#1094457 : SLE 15 modules are still in BETA while product enter GMC phase');
            assert_screen('scc-beta-filter-checkbox');
            send_key('alt-i');
        }
        assert_screen($modules_needle);
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

    if (check_var('SCC_REGISTER', 'installation') || check_var('SCC_REGISTER', 'yast') || check_var('SCC_REGISTER', 'console')) {
        # The value of SCC_ADDONS is a list of abbreviation of addons/modules
        # Following are abbreviations defined for modules and some addons
        #
        # sdk - Software Development Kit
        # we - Workstation
        # ha - High Availability
        # geo - Geo Clustering for SUSE Linux Enterprise High Availability
        # ltss - Long Term Service Pack Support
        # live - Live Patching
        # asmm - Advanced System Management Module
        # certm - Certifications Module
        # contm - Containers Module
        # hpcm - HPC Module
        # lgm - Legacy Module
        # pcm - Public Cloud Module
        # tcm - Toolchain Module
        # wsm - Web and Scripting Module
        # idu - IBM DLPAR Utils (ppc64le only)
        # ids - IBM DLPAR sdk (ppc64le only)
        # phub - PackageHub
        # ses - SUSE Enterprise Storage
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
            # remove emty elements
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
                    if ($addon eq 'phub') {
                        # Record soft-failure for 12-SP4 and 15-SP1
                        my $bugref =
                          is_sle('=12-SP4')   ? 'bsc#1092568'
                          : is_sle('=15-SP1') ? 'bsc#1106085'
                          :                     undef;
                        if ($bugref) {
                            record_soft_failure $bugref;
                            next;
                        }
                    }
                    send_key_until_needlematch ["scc-module-$addon", "scc-module-$addon-selected"], "down", 40;
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
                    assert_screen "scc-module-$addon-selected";
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
            my $counter = 50;
            while ($counter--) {
                die 'Addon registration repeated too much. Check if SCC is down.' if ($counter eq 1);
                assert_screen [
                    qw(import-untrusted-gpg-key yast_scc-pkgtoinstall yast-scc-emptypkg inst-addon contacting-registration-server refreshing-repository)];
                if (match_has_tag('import-untrusted-gpg-key')) {
                    if (!check_screen(\@known_untrusted_keys, 0)) {
                        die 'untrusted gpg key';
                    }
                    wait_screen_change {
                        send_key 'alt-t';
                    };
                    next;
                }
                elsif (match_has_tag('yast_scc-pkgtoinstall')) {
                    # yast shows the software install dialog
                    wait_screen_change { send_key 'alt-a' };
                    while (
                        assert_screen(
                            ['yast_scc-license-dialog', 'yast_scc-automatic-changes', 'yast_scc-prompt-reboot', 'yast_scc-installation-summary'], 900
                        ))
                    {
                        if (match_has_tag('yast_scc-license-dialog')) {
                            send_key 'alt-a';
                            next;
                        }
                        # yast may pop up dependencies or reboot prompt window
                        if (match_has_tag('yast_scc-automatic-changes') or match_has_tag('unsupported-packages') or match_has_tag('yast_scc-prompt-reboot')) {
                            send_key 'alt-o';
                            next;
                        }
                        if (match_has_tag('yast_scc-installation-summary')) {
                            send_key 'alt-f';
                            last;
                        }
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
    else {
        if (!get_var('SCC_REGISTER', '') =~ /addon|network/) {
            send_key $cmd{next};
        }
    }
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
    type_string registration_bootloader_cmdline, $max_interval;
    save_screenshot;
}

sub yast_scc_registration {
    type_string "yast2 scc; echo yast-scc-done-\$?- > /dev/$serialdev\n";
    assert_screen_with_soft_timeout(
        'scc-registration',
        timeout      => 90,
        soft_timeout => 30,
        bugref       => 'wait longer time to start yast2 scc in case of multiple jobs start to execute it in parallel on a same worker'
    );

    fill_in_registration_data;

    my $ret = wait_serial "yast-scc-done-\\d+-";
    die "yast scc failed" unless (defined $ret && $ret =~ /yast-scc-done-0-/);

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
        'ha'    => 'sle-ha',
        'geo'   => 'sle-ha-geo',
        'we'    => 'sle-we',
        'sdk'   => 'sle-sdk',
        'ses'   => 'ses',
        'live'  => 'sle-live-patching',
        'asmm'  => 'sle-module-adv-systems-management',
        'contm' => 'sle-module-containers',
        'hpcm'  => 'sle-module-hpc',
        'lgm'   => 'sle-module-legacy',
        'pcm'   => 'sle-module-public-cloud',
        'tcm'   => 'sle-module-toolchain',
        'wsm'   => 'sle-module-web-scripting',
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
        if (is_sle('12-sp3+')) {
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
    if (sle_version_at_least('12-SP1', version_variable => $args{version_variable})) {
        assert_script_run('SUSEConnect -d --cleanup', 200);
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

    for my $a (split(/,/, get_var('SCC_ADDONS'))) {
        push @addons_new, defined $addons_map{$a} ? $addons_map{$a} : $a;
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

1;
