# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package version_utils;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi qw(check_var get_var set_var script_output);
use version 'is_lax';
use Carp 'croak';
use Utils::Backends;
use Utils::Architectures;

use constant {
    VERSION => [
        qw(
          is_sle
          is_pre_15
          is_microos
          is_leap_micro
          is_sle_micro
          is_alp
          is_selfinstall
          is_gnome_next
          is_jeos
          is_krypton_argon
          is_leap
          is_opensuse
          is_tumbleweed
          is_rescuesystem
          is_sles4sap
          is_sles4sap_standard
          is_sles4migration
          is_released
          is_rt
          is_hpc
          is_staging
          is_storage_ng
          is_using_system_role
          is_using_system_role_first_flow
          is_public_cloud
          is_openstack
          is_leap_migration
          requires_role_selection
          check_version
          get_os_release
          check_os_release
          package_version_cmp
          get_version_id
        )
    ],
    BACKEND => [
        qw(
          is_vmware
          is_hyperv
          is_hyperv_in_gui
          is_aarch64_uefi_boot_hdd
          is_svirt_except_s390x
        )
    ],
    SCENARIO => [
        qw(
          install_this_version
          install_to_other_at_least
          is_upgrade
          is_sle12_hdd_in_upgrade
          is_installcheck
          is_desktop_installed
          is_system_upgrading
          is_virtualization_server
          is_server
          is_transactional
          is_livecd
          is_quarterly_iso
          uses_qa_net_hardware
          has_test_issues
        )
    ]
};

=head1 VERSION_UTILS

=head1 SYNOPSIS

Contains all the functions related to version checking
=cut

our @EXPORT = (@{(+VERSION)}, @{(+SCENARIO)}, @{+BACKEND});

our %EXPORT_TAGS = (
    VERSION => (VERSION),
    BACKEND => (BACKEND),
    SCENARIO => (SCENARIO)
);

=head2 is_jeos

Returns true if called on jeos
=cut

sub is_jeos {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

=head2 is_vmware

Returns true if called on vmware
=cut

sub is_vmware {
    return check_var('VIRSH_VMM_FAMILY', 'vmware');
}

=head2 is_krypton_argon

Returns true if called on krypton or argon
=cut

sub is_krypton_argon {
    return get_var('FLAVOR', '') =~ /(Krypton|Argon)/;
}

=head2 is_gnome_next

Returns true if called on Gnome-Live
=cut

sub is_gnome_next {
    return get_var('FLAVOR', '') =~ /Gnome-Live/;
}

=head2 is_installcheck

Returns true if 'INSTALLCHECK' is set
=cut

sub is_installcheck {
    return get_var('INSTALLCHECK');
}

=head2 is_rescuesystem

Returns true if called on a rescue system
=cut

sub is_rescuesystem {
    return get_var('RESCUESYSTEM');
}

=head2 is_virtualization_server

Returns true if called on a virutalization server
=cut

sub is_virtualization_server {
    return get_var('SYSTEM_ROLE', '') =~ /(kvm|xen)/;
}

=head2 is_livecd

Returns true if executed on a live cd
=cut

sub is_livecd {
    return get_var("LIVECD");
}

=head2 check_version

Usage: check_version('>15.0', get_var('VERSION'), '\d{2}')
Query format: [= > < >= <=] version [+] (Example: <=12-sp3 =12-sp1 <4.0 >=15 3.0+)
Check agains: product version to check against - probably get_var('VERSION')
Regex format: checks query version format (Example: /\d{2}\.\d/)#
=cut

sub check_version {
    my $query = lc shift;
    my $pv = lc shift;
    my $regex = shift // qr/[^<>=+]+/;

    # Matches operator($op), version($qv), plus($plus) - regex101.com to debug ;)
    if ($query =~ /^(?(?!.*\+$)(?<op>[<>=]|[<>]=))(?<qv>$regex)(?<plus>\+)?$/i) {
        my $qv = $+{qv} or die "Query $query not matching required format $regex";

        # Compare versions if they can be parsed
        if (is_lax($pv) && is_lax($qv)) {
            $pv = version->declare($pv);
            $qv = version->declare($qv);
        }
        return $pv ge $qv if $+{plus} || $+{op} eq '>=';
        return $pv le $qv if $+{op} eq '<=';
        return $pv gt $qv if $+{op} eq '>';
        return $pv lt $qv if $+{op} eq '<';
        return $pv eq $qv if $+{op} eq '=';
    }
    # Version should be matched and processed by now
    croak "Unsupported version parameter for check_version: '$query'";
}

=head2 is_microos

Check if distribution is openSUSE MicroOS with optional filter:
Media type: DVD (iso) or VMX (all disk images)
Version: Tumbleweed | 15.2 (Leap)
Flavor: DVD | MS-HyperV | XEN | KVM-and-Xen | ..
=cut

sub is_microos {
    my $filter = shift;
    my $distri = get_var('DISTRI');
    my $flavor = get_var('FLAVOR');
    my $version = get_var('VERSION');
    return 0 unless $distri && $distri =~ /microos/;
    return 1 unless $filter;

    my $version_is_tw = ($version =~ /Tumbleweed/ || $version =~ /^Staging:/);

    if ($filter eq 'DVD') {
        return $flavor =~ /DVD/;    # DVD and Staging-?-DVD
    }
    elsif ($filter eq 'VMX') {
        return $flavor !~ /DVD/;    # If not DVD it's VMX
    }
    elsif ($filter eq 'Tumbleweed') {
        return $version_is_tw;
    }
    elsif ($filter =~ /\d\.\d\+?$/) {
        # If we use '+' it means "this or newer", which includes tumbleweed
        return ($filter =~ /\+$/) if $version_is_tw;
        return check_version($filter, $version, qr/\d{1,}\.\d/);
    }
    else {
        return $flavor eq $filter;    # Specific FLAVOR selector
    }
}

=head2 is_leap_micro

Check if distribution is openSUSE Leap Micro
=cut

sub is_leap_micro {
    my $query = shift;
    my $version = shift // get_var('VERSION');

    return 0 unless check_var('DISTRI', 'leap-micro');
    return 1 unless $query;

    # Version check
    return check_version($query, $version, qr/\d{1,}\.\d/);
}

=head2 is_sle_micro

Check if distribution is SUSE Linux Enterprise Micro
=cut

sub is_sle_micro {
    my $query = shift;
    my $version = shift // get_var('VERSION');

    return 0 unless check_var('DISTRI', 'sle-micro');
    return 1 unless $query;

    # Version check
    return check_version($query, $version, qr/\d{1,}\.\d/);
}

=head2 is_alp

Check if distribution is ALP
=cut

sub is_alp {
    my $query = shift;
    my $version = shift // get_var('VERSION');

    return 0 unless check_var('DISTRI', 'alp');
    return 1 unless $query;

    # Version check
    return check_version($query, $version, qr/\d{1,}\.\d/);
}

=head2 is_selfinstall

Check if SLEM is in flavor of self installable iso
=cut

sub is_selfinstall {
    return get_var('FLAVOR') =~ /selfinstall/i;
}

=head2 is_tumbleweed

Returns true if called on tumbleweed
=cut

sub is_tumbleweed {
    # Tumbleweed and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if get_var('VERSION') =~ /Tumbleweed/;
    return 1 if is_gnome_next;
    return get_var('VERSION') =~ /^Staging:/;
}

=head2 is_leap

Check if distribution is Leap with optional filter for:
Version: <=42.2 =15.0 >15.0 >=42.3 15.0+
=cut

sub is_leap {
    my $query = shift;
    my $version = get_var('VERSION', '');

    # Leap and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 0 unless $version =~ /^\d{2,}\.\d/ || $version =~ /^Jump/;
    # GNOME-Next is 'mean' as it can be VERSION=42.0, easily to be confused with Leap 42.x
    # But GNOME-Next is always based on Tumbleweed
    return 0 if is_gnome_next;
    return 1 unless $query;

    # Hacks for staging and HG2G :)
    $query =~ s/^([<>=]*)42/${1}14/;
    $version =~ s/^42/14/;
    $version =~ s/:(Core|S)[:\w]*//i;
    $version =~ s/^Jump://i;

    return check_version($query, $version, qr/\d{2,}\.\d/);
}

=head2 is_opensuse

Returns true if called on opensuse
=cut

sub is_opensuse {
    return 1 if check_var('DISTRI', 'opensuse');
    return 1 if check_var('DISTRI', 'microos');
    return 1 if check_var('DISTRI', 'leap-micro');
    return 1 if check_var('DISTRI', 'alp');
    return 0;
}

=head2 is_sle

Check if distribution is SLE with optional filter for:
Version: <=12-sp3 =12-sp1 >11-sp1 >=15 15+ (>=15 and 15+ are equivalent)
=cut

sub is_sle {
    my $query = shift;
    my $version = shift // get_var('VERSION');

    return 0 unless check_var('DISTRI', 'sle');
    return 1 unless $query;

    # Version check
    return check_version($query, $version, qr/\d{2}(?:-sp\d)?/);
}

=head2 is_transactional

Returns true if called on a transactional server
=cut

sub is_transactional {
    return 1 if (is_microos || is_sle_micro || is_leap_micro);
    return 1 if (is_alp && get_var('FLAVOR') !~ /NonTransactional/);
    return check_var('SYSTEM_ROLE', 'serverro') || get_var('TRANSACTIONAL_SERVER');
}

=head2 is_sles4migration

Returns true if called in a migration scenario
=cut

sub is_sles4migration {
    return get_var('FLAVOR', '') =~ /Migration|migrated/ && check_var('SLE_PRODUCT', 'sles');
}

=head2 is_sles4sap

Returns true if called in a SAP test
=cut

sub is_sles4sap {
    return get_var('FLAVOR', '') =~ /SAP/ || check_var('SLE_PRODUCT', 'sles4sap');
}

=head2 is_sles4sap_standard

Returns true if called in an SAP standard test
=cut

sub is_sles4sap_standard {
    return is_sles4sap && check_var('SLES4SAP_MODE', 'sles');
}

=head2 is_rt

Returns true if called on a real time system
=cut

sub is_rt {
    return (check_var('SLE_PRODUCT', 'rt') || get_var('FLAVOR') =~ /rt/i);
}

=head2 is_hpc

Returns true if called in an HPC test
=cut

sub is_hpc {
    return check_var('SLE_PRODUCT', 'hpc');
}

=head2 is_released

Returns true if called on a released build
=cut

sub is_released {
    return get_var('FLAVOR') =~ /Incidents|Updates|QR/;
}


=head2 is_staging

Returns true if called in staging
=cut

sub is_staging {
    return get_var('STAGING');
}

=head2 is_storage_ng

Returns true if storage_ng is used
=cut

sub is_storage_ng {
    return get_var('STORAGE_NG') || is_sle('15+');
}

=head2 is_upgrade

Returns true in upgrade scenarios
=cut

sub is_upgrade {
    return get_var('UPGRADE') || get_var('ONLINE_MIGRATION') || get_var('ZDUP') || get_var('AUTOUPGRADE') || get_var('LIVE_UPGRADE');
}

=head2 is_sle12_hdd_in_upgrade

Returns true if called in SLES12 upgrade scenario
=cut

sub is_sle12_hdd_in_upgrade {
    return is_upgrade && is_sle('<15', get_var('HDDVERSION'));
}

=head2 is_desktop_installed

Returns true if a desktop is installed
=cut

sub is_desktop_installed {
    return get_var("DESKTOP") !~ /textmode|minimalx/;
}

=head2 is_system_upgrading

#TODO this should be documented
=cut

sub is_system_upgrading {
    # If PATCH=1, make sure patch action is finished
    return is_upgrade && (!get_var('PATCH') || (get_var('PATCH') && get_var('SYSTEM_PATCHED')));
}

=head2 is_pre15

Returns if system is older than SLE or Leap 15
=cut

sub is_pre_15 {
    return (is_sle('<15') || is_leap('<15.0')) && !is_tumbleweed;
}

=head2 is_aarch64_uefi_boot_hdd

Returns true if system is aarch64 with uefi and shall boot an hdd image
=cut

sub is_aarch64_uefi_boot_hdd {
    return get_var('MACHINE') =~ /aarch64/ && get_var('UEFI') && get_var('BOOT_HDD_IMAGE');
}

=head2 is_server

Returns true if executed on a server pattern, SLES4SAP or SLES4MIGRATION
=cut

sub is_server {
    return 1 if is_sles4sap();
    return 1 if is_sles4migration();
    return 1 if get_var('FLAVOR', '') =~ /^Server/;
    return 1 if get_var('PUBLIC_CLOUD');
    # If unified installer, we need to check SLE_PRODUCT
    return 0 if get_var('FLAVOR', '') !~ /^Installer-|^Online|^Full/;
    return check_var('SLE_PRODUCT', 'sles');
}

=head2 install_this_version

Returns true if INSTALL_TO_OTHERS is not set
=cut

sub install_this_version {
    return !check_var('INSTALL_TO_OTHERS', 1);
}

=head2 install_to_other_at_least

Check the real version of the test machine is at least some value, rather than the VERSION variable
It is for version checking for tests with variable "INSTALL_TO_OTHERS".
=cut

sub install_to_other_at_least {
    my $version = shift;

    if (!check_var("INSTALL_TO_OTHERS", "1")) {
        return 0;
    }

    #setup the var for real VERSION
    my $real_installed_version = get_var("REPO_0_TO_INSTALL");
    $real_installed_version =~ /.*SLES?-(\d+-SP\d+)-.*/m;
    $real_installed_version = $1;
    set_var("REAL_INSTALLED_VERSION", $real_installed_version);
    bmwqemu::save_vars();

    return is_sle(">=$version", $real_installed_version);
}

=head2 is_using_system_role

system_role selection during installation was added as a new feature since sles12sp2
so system_role.pm should be loaded for all tests that actually install to versions over sles12sp2
no matter with or without INSTALL_TO_OTHERS tag
On SLE 15 SP0 we unconditionally have system roles screen
SLE 15 SP1:
    * Has system roles only if more than one is available, meaning either registered or with all packages DVD;
    * RT Product has only one (minimal) role.
On microos, leap 15.1+, TW we have it instead of desktop selection screen
=cut

sub is_using_system_role {
    return is_sle('>=12-SP2') && is_sle('<15')
      && is_x86_64
      && is_server()
      && (!is_sles4sap() || is_sles4sap_standard())
      && (install_this_version() || install_to_other_at_least('12-SP2'))
      || (is_sles4sap() && main_common::is_updates_test_repo())
      || is_sle('=15')
      || (is_sle('>15') && (check_var('SCC_REGISTER', 'installation') || get_var('ADDONS') || get_var('ADDONURL')))
      || (is_sle('15-SP2+') && check_var('FLAVOR', 'Full'))
      || (is_opensuse && !is_leap('<15.1'))    # Also on leap 15.1, TW, MicroOS
}

=head2 is_using_system_role_first_flow

On leap 15.0 we have desktop selection first, and everywhere, where we have system roles
=cut

sub is_using_system_role_first_flow {
    return is_leap('=15.0') || is_using_system_role;
}

=head2 requires_role_selection

If there is only one role, there is no selection offered
=cut

sub requires_role_selection {
    # Applies to Krypton and Argon based on Leap 15.1+
    return !is_krypton_argon;
}

=head2 has_product_selection

    has_product_selection;

Identify cases when Installer has to show Product Selection screen.

Starting with SLE 15, all products are distributed using one medium, and Product
to install has to be chosen explicitly.

Though, there are some exceptions (like s390x on Sle15 SP0) when there is only
one Product, so that License agreement is shown directly, skipping the Product
selection step. Also, Product Selection screen is not shown during upgrade.
on SLE 15+, zVM preparation test shouldn't show Product Selection screen.

Returns true (1) if Product Selection step has to be shown for the certain
configuration, otherwise returns false (0).
=cut

sub has_product_selection {
    # Product selection behavior changed for s390 on 15-SP4, so now there's only a single product
    # and there's no need for the installer to request anything, however for QU this might change
    # following PR should be used as a reference for when product selection changes again in the
    # future
    # https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/13880
    my $does_not_have = is_sle('>=15-SP4') && check_var('FLAVOR', 'Full') && is_s390x();
    if (is_sle('15+') && !get_var('UPGRADE')) {
        return 0 if $does_not_have;
        return (is_sle('>=15-SP1') || !is_s390x()) && !get_var('BASE_VERSION');
    }
}

=head2 has_license_on_welcome_screen

    has_license_on_welcome_screen;

Identify cases when License Agreement has to be shown on Welcome screen and should be accepted there.

Returns true (1) if License Agreement has to be shown on Welcome screen for the certain
configuration, otherwise returns false (0).

=cut

sub has_license_on_welcome_screen {
    return 1 if is_sle_micro;
    if (get_var('HASLICENSE')) {
        return 1 if (
            ((is_sle('>=15-SP1') && get_var('BASE_VERSION') && !get_var('UPGRADE')) && is_s390x())
            || is_sle('<15')
            || (is_sle('=15') && is_s390x())
            || (is_sle('>=15-SP4') && check_var('FLAVOR', 'Full') && is_s390x() && !get_var('UPGRADE'))
        );
    }

    return 0;
}

=head2 has_license_to_accept

Returns true if the system has a license that needs to be accepted
=cut

sub has_license_to_accept {
    return has_license_on_welcome_screen || has_product_selection;
}

=head2 uses_qa_net_hardware

Returns true if the SUT uses qa net hardware
=cut

sub uses_qa_net_hardware {
    return !check_var("IPXE", "1") && is_ipmi || check_var("BACKEND", "generalhw");
}

=head2 get_os_release

Get SLE release version, service pack and distribution name info from any running sles os without any dependencies
It parses the info from /etc/os-release file, which can reside in any physical host or virtual machine
The file can also be placed anywhere as long as it can be reached somehow by its absolute file path,
which should be passed in as the second argument os_release_file, for example, "/etc/os-release"
At the same time, connection method to the entity in which the file reside should be passed in as the
firt argument go_to_target, for example, "ssh root at name or ip address" or "way to download the file"
For use only on locahost, no argument needs to be specified
=cut

sub get_os_release {
    my ($go_to_target, $os_release_file) = @_;
    $go_to_target //= '';
    $os_release_file //= '/etc/os-release';
    my %os_release = script_output("$go_to_target cat $os_release_file") =~ /^([^#]\S+)="?([^"\r\n]+)"?$/gm;
    %os_release = map { uc($_) => $os_release{$_} } keys %os_release;
    ($os_release{VERSION}) = $os_release{VERSION} =~ /(^\d+\S*\d*)/im;
    my ($os_version, $os_service_pack) = split(/\.|-sp/i, $os_release{VERSION});
    $os_service_pack //= 0;
    return $os_version, $os_service_pack, $os_release{ID};
}

=head2 check_os_release

Identify running os without any dependencies parsing the I</etc/os-release>.

=item C<distri_name>

The expected distribution name to compare.

=item C<line>

The line we'll be parsing and checking.

=item C<go_to_target>

Command connecting to the SUT

=item C<os_release_file>

The full path to the Operating system identification file.
Default to I</etc/os-release>.

Returns 1 (true) if the ID_LIKE variable contains C<distri_name>.

=cut

sub check_os_release {
    my ($distri_name, $line, $go_to_target, $os_release_file) = @_;
    die '$distri_name is not given' unless $distri_name;
    die '$line is not given' unless $line;
    $go_to_target //= '';
    $os_release_file //= '/etc/os-release';
    my $os_like_name = script_output("$go_to_target grep -e \"^$line\\b\" ${os_release_file} | cut -d'\"' -f2");
    return ($os_like_name =~ /$distri_name/i);
}

=head2 is_public_cloud

Returns true if PUBLIC_CLOUD is set to 1
=cut

sub is_public_cloud {
    return get_var('PUBLIC_CLOUD');
}

=head2 is_openstack

Returns true if JEOS_OPENSTACK is set to 1

=cut

sub is_openstack {
    return get_var('JEOS_OPENSTACK');
}

=head2 is_leap_migration

Returns true if called in a leap to sle migration scenario
=cut

sub is_leap_migration {
    return is_upgrade && get_var('ORIGIN_SYSTEM_VERSION') =~ /leap/;
}

=head2 has_test_issues

Returns true if test issues are present (i.e. is update tests are present)

=cut

sub has_test_issues() {
    if (is_opensuse) {
        return 1 if (get_var('OS_TEST_ISSUES') ne "");
    } elsif (is_sle) {
        return 1 if (get_var('BASE_TEST_ISSUES') ne "");
        return 1 if (get_var('CONTM_TEST_ISSUES') ne "");
        return 1 if (get_var('DESKTOP_TEST_ISSUES') ne "");
        return 1 if (get_var('LEGACY_TEST_ISSUES') ne "");
        return 1 if (get_var('OS_TEST_ISSUES') ne "");
        return 1 if (get_var('PYTHON2_TEST_ISSUES') ne "");
        return 1 if (get_var('SCRIPT_TEST_ISSUES') ne "");
        return 1 if (get_var('SDK_TEST_ISSUES') ne "");
        return 1 if (get_var('SERVERAPP_TEST_ISSUES') ne "");
        return 1 if (get_var('WE_TEST_ISSUES') ne "");
    }
    return 0;
}

=head2 package_version_cmp

Compare two SUSE-style version strings. Returns an integer that is less than,
equal to, or greater than zero if the first argument is less than, equal to,
or greater than the second one, respectively.

=cut

sub package_version_cmp {
    my ($ver1, $ver2) = @_;

    my @chunks1 = split(/-/, $ver1);
    my @chunks2 = split(/-/, $ver2);
    my $chunk_cnt = $#chunks1 > $#chunks2 ? scalar @chunks1 : scalar @chunks2;

    for (my $cid = 0; $cid < $chunk_cnt; $cid++) {
        my @tokens1 = split(/\./, $chunks1[$cid] // '0');
        my @tokens2 = split(/\./, $chunks2[$cid] // '0');
        my $token_cnt = scalar @tokens1;
        $token_cnt = scalar @tokens2 if $#tokens2 > $#tokens1;

        for (my $tid = 0; $tid < $token_cnt; $tid++) {
            my $tok1 = $tokens1[$tid] // '0';
            my $tok2 = $tokens2[$tid] // '0';

            if ($tok1 =~ m/^\d+$/ && $tok2 =~ m/^\d+$/) {
                next if $tok1 == $tok2;
                return $tok1 - $tok2;
            } else {
                next if $tok1 eq $tok2;
                return 1 if $tok1 gt $tok2;
                return -1;
            }
        }
    }

    return 0;
}

=head2 is_quarterly_iso

Returns true if called in quaterly iso testing
=cut

sub is_quarterly_iso {
    return 1 if get_var('FLAVOR', '') =~ /QR/;
}

=head2 get_version_id

  get_version_id(dst_machine => 'machine')

Get SLES version from VERSION_ID in /etc/os-release. This subroutine also supports
performing query on remote machine if dst_machine is given specific ip address or
fqdn text of the remote machine. The default location that contains VERSION_ID is
file /etc/os-release if nothing else is passed in to argument verid_file.

=cut

sub get_version_id {
    my (%args) = @_;
    $args{dst_machine} //= 'localhost';
    $args{verid_file} //= '/etc/os-release';

    my $cmd = "cat $args{verid_file} | grep VERSION_ID | grep -Eo \"[[:digit:]]{1,}\\.[[:digit:]]{1,}\"";
    $cmd = "ssh root\@$args{dst_machine} " . "$cmd" if ($args{dst_machine} ne 'localhost');
    return script_output($cmd);
}
