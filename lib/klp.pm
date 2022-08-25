# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

package klp;

use warnings;
use strict;

use Exporter 'import';

use testapi;
use utils;
use version_utils 'is_sle';

our @EXPORT = qw(
  install_klp_product is_klp_pkg find_installed_klp_pkg klp_pkg_eq
  verify_klp_pkg_installation verify_klp_pkg_patch_is_active
);

sub install_klp_product {
    my $arch = get_required_var('ARCH');
    my $version = get_required_var('VERSION');
    my $livepatch_repo = get_var('REPO_SLE_MODULE_LIVE_PATCHING');
    my $release_override;
    my $lp_product;
    my $lp_module;
    if ($version eq '12') {
        $release_override = '-d';
    }
    if (!is_sle('>=12-SP3')) {
        $version = '12';
    }
    # SLE15 has different structure of modules and products than SLE12
    if (is_sle('15+')) {
        $lp_product = 'sle-module-live-patching';
        $lp_module = 'SLE-Module-Live-Patching';
    }
    else {
        $lp_product = 'sle-live-patching';
        $lp_module = 'SLE-Live-Patching';
    }

    if ($livepatch_repo) {
        zypper_ar("$utils::OPENQA_FTP_URL/$livepatch_repo", name => "repo-live-patching");
    }
    else {
        zypper_ar("http://download.suse.de/ibs/SUSE/Products/$lp_module/$version/$arch/product/", name => "kgraft-pool");
        zypper_ar("$release_override http://download.suse.de/ibs/SUSE/Updates/$lp_module/$version/$arch/update/", name => "kgraft-update");
    }

    # install kgraft product
    zypper_call("in -l -t product $lp_product", exitcode => [0, 102, 103]);
    zypper_call("mr -e kgraft-update") unless $livepatch_repo;
}

sub is_klp_pkg {
    my $pkg = shift;
    my $base = qr/(?:kgraft-|kernel-live)patch/;

    if ($$pkg{name} =~ m/^${base}-\d+/) {
        if ($$pkg{name} =~ m/^${base}-(\d+_\d+_\d+-\d+_*\d*_*\d*)-([a-z][a-z0-9]*)$/) {
            my $kver = $1;
            my $kflavor = $2;
            $kver =~ s/_/./g;
            return {
                name => $$pkg{name},
                version => $$pkg{version},
                kver => $kver,
                kflavor => $kflavor,
            };

        } else {
            die "Unexpected kernel livepatch package name format: \"$$pkg{name}\"";
        }
    }

    return undef;
}

sub klp_pkg_eq {
    my ($klp_pkg1, $klp_pkg2) = @_;

    return ($$klp_pkg1{name} eq $$klp_pkg2{name} &&
          $$klp_pkg1{version} eq $$klp_pkg2{version});
}

sub find_installed_klp_pkg {
    my ($kver, $kflavor) = @_;

    my $pkgs = zypper_search("-s -i -t package");
    my $klp_pkg;
    foreach my $pkg (@$pkgs) {
        my $cur_klp_pkg = is_klp_pkg($pkg);

        if ($cur_klp_pkg &&
            $$cur_klp_pkg{kver} eq $kver &&
            $$cur_klp_pkg{kflavor} eq $kflavor) {
            if ($klp_pkg && !klp_pkg_eq($klp_pkg, $cur_klp_pkg)) {
                die "Multiple live patch packages installed for kernel";
            }

            $klp_pkg = $cur_klp_pkg;
        }
    }

    return $klp_pkg;
}

sub _klp_pkg_get_kernel_modules {
    my $klp_pkg = shift;

    my @modules;
    my $output = script_output("rpm -ql '$$klp_pkg{name}-$$klp_pkg{version}'");
    for my $line (split /\n/, $output) {
        if ($line =~ /\.ko$/) {
            push @modules, $line;
        }
    }

    if (!@modules) {
        die "No kernel modules provided by \"$$klp_pkg{name}-$$klp_pkg{version}\"";
    }

    return \@modules;
}

sub klp_pkg_get_kernel_modules {
    my $klp_pkg = shift;

    if (!exists($$klp_pkg{kmods_cached})) {
        $$klp_pkg{kmods_cached} = _klp_pkg_get_kernel_modules($klp_pkg);
    }

    return $$klp_pkg{kmods_cached};
}

sub _klp_pkg_get_gitrev {
    my $klp_pkg = shift;

    my $pkg_name = "$$klp_pkg{name}-$$klp_pkg{version}";
    my $output = script_output("rpm -qi '$pkg_name'");
    my $gitrev;
    for my $line (split /\n/, $output) {
        if ($line =~ /^GIT Revision:\s+([a-z0-9]+)$/) {
            if ($gitrev) {
                die "Multiple GIT revisions found in description for package '$pkg_name'";
            }

            $gitrev = lc($1);
        }
    }
    if (!$gitrev) {
        die "No GIT revision found in description for package '$pkg_name'";
    }

    return $gitrev;
}

sub klp_pkg_get_gitrev {
    my $klp_pkg = shift;

    if (!exists($$klp_pkg{gitrev_cached})) {
        $$klp_pkg{gitrev_cached} = _klp_pkg_get_gitrev($klp_pkg);
    }

    return $$klp_pkg{gitrev_cached};
}

sub verify_initrd_for_klp_pkg {
    my $klp_pkg = shift;

    # Inspect that the target kernel's initrd has been repopulated
    # with all the required content, namely the livepatching dracut
    # module and all kernel modules provided by the given livepatch
    # package.
    my %req_kmods = map { $_ => 0 } @{klp_pkg_get_kernel_modules($klp_pkg)};
    my $dracut_module_found = 0;

    my $initrd = "/boot/initrd-$$klp_pkg{kver}-$$klp_pkg{kflavor}";
    my $output = script_output("lsinitrd '$initrd'");
    for my $line (split /\n/, $output) {
        my @line = split(/\s/, $line);
        if (!@line) {
            next;
        }
        elsif (@line == 1 &&
            ($line[0] eq 'kernel-livepatch' ||
                $line[0] eq 'kgraft')) {
            $dracut_module_found = 1;
        }
        elsif ($line[$#line] =~ /\.ko$/) {
            my $kmod = "/$line[$#line]";
            if (exists($req_kmods{$kmod})) {
                $req_kmods{$kmod} = 1;
            }
        }
    }

    if (!$dracut_module_found) {
        die "Kernel live patch dracut module not found in \"$initrd\"";
    }

    while (my ($kmod, $found) = each(%req_kmods)) {
        if (!$found) {
            die "Kernel module \"$kmod\" not found in \"$initrd\"";
        }
    }
}

sub verify_klp_pkg_installation {
    my $klp_pkg = shift;
    verify_initrd_for_klp_pkg($klp_pkg);
}

sub _klp_tool {
    if (!is_sle('15+')) {
        return "kgr";
    }
    return "klp";
}

sub klp_tool_patches {
    my $klp_tool = _klp_tool();
    my $output = script_output("$klp_tool -v patches");

    my @patches;
    my $cur_patch;
    for my $line (split /\n/, $output) {
        # Lines with fields further describing the current patch are
        # prefixed by whitespace.
        if ($line =~ /^\s/) {
            if (!$cur_patch ||
                !($line =~ /^\s+([^:]+):\s*(.*)/)) {
                die "Unexpected output from '$klp_tool patches': $line";
            }

            $$cur_patch{$1} = $2;
        }
        elsif (length($line)) {
            $cur_patch = {name => $line};
            push @patches, $cur_patch;
        } else {
            $cur_patch = undef;
        }
    }

    return \@patches;
}

sub klp_wait_for_transition {
    my $klp_tool = _klp_tool();
    my $timeout = 61;

    while ($timeout--) {
        my $output = script_output("$klp_tool status");
        chomp($output);
        if ($output eq 'ready') {
            last;
        } elsif ($output eq 'in_progress') {
            sleep(1) unless !$timeout;
        } else {
            die "Unrecognized output from '$klp_tool status': '$output'";
        }
    }

    if (!$timeout) {
        die "Kernel livepatch transition did not finish in time";
    }

    # As an additional sanity check, verify that the list of blocking
    # tasks as reported by '$klp_tool blocking' is empty.
    my $output = script_output("$klp_tool blocking");
    chomp($output);
    if (length($output)) {
        die "$klp_tool reported blocking tasks in ready state: '$output'";
    }
}

sub _get_kernel_tainted {
    my $tainted = script_output("sysctl kernel.tainted");

    if (!($tainted =~ m/^kernel.tainted\s*=\s*([0-9]+)$/)) {
        die "Unrecognized output from 'sysctl kernel.tainted': '$tainted'";
    }

    return int($1);
}

sub is_kernel_tainted {
    my $mask = shift;
    my $tainted = _get_kernel_tainted();

    return ($tainted & $mask);
}

sub verify_klp_pkg_patch_is_active {
    my $klp_pkg = shift;

    # Wait for the current livepatch transition, if any, to complete.
    klp_wait_for_transition();

    # Verify that 'klp patches' reports the expected livepatch
    # name. Note that the livepatch name displayed by 'klp patches' is
    # the corresponding module's KBUILD_MODNAME.
    my $kmods = klp_pkg_get_kernel_modules($klp_pkg);
    if (@$kmods != 1) {
        die "No support for livepatch packages with multiple kernel modules";
    }

    my $klp_name = $$kmods[0];
    $klp_name =~ s/\.ko$//;    # strip suffix
    $klp_name =~ s,^([^/]*/)*,,;    # strip directory
    $klp_name =~ tr/ ,-/:__/;    # transform to KBUILD_MODNAME

    my $patches = klp_tool_patches();
    my $active_patch;
    foreach my $cur_patch (@$patches) {
        if (!exists $$cur_patch{active}) {
            die "No 'active' field for '$$cur_patch{name}' in 'klp patches' output";
        }

        if ($$cur_patch{active} eq '1') {
            if ($active_patch) {
                die "More than one kernel livepatch active";
            }
            $active_patch = $cur_patch;
        }
    }

    if (!$active_patch) {
        die "No active kernel livepatch found";
    }
    elsif ($$active_patch{name} ne $klp_name) {
        die "Expected active kernel livepatch '$klp_name', got '$$active_patch{name}'";
    }

    # As an additional sanity check, verify that the RPM reported by
    # $klp_tool matches what would be expected from the given
    # $klp_pkg.
    if (!exists $$active_patch{RPM}) {
        die "No 'RPM' field for $klp_name in 'klp patches' output";
    }

    my $rpm = $$active_patch{RPM};
    $rpm =~ s/\.[^.]+$//;    # strip arch suffix
    if ($rpm ne "$$klp_pkg{name}-$$klp_pkg{version}") {
        die "Expected active livepatch from package '$$klp_pkg{name}', got '$rpm'";
    }

    # Check that uname -v has changed, i.e. that the reported
    # livepatch git revision matches the one from the package
    # description.
    my $output = script_output("uname -v");
    my $uname_pattern = '\([a-z0-9]+/(?:lp|kGraft)\)$';
    my $uses_gitrev = is_sle('<15-sp4');

    chomp($output);

    if ($uses_gitrev) {
        $uname_pattern = '\([a-z0-9]+/(?:lp|kGraft)-([a-z0-9]+)\)$';
    }

    unless ($output =~ m,$uname_pattern,i) {
        die "Unable to recognize livepatch tag in 'uname -v' output: '$output'";
    }

    if ($uses_gitrev) {
        my $uname_v_gitrev = lc($1);
        my $pkgdesc_gitrev = klp_pkg_get_gitrev($klp_pkg);
        my $pkgdesc_gitrev_len = length($pkgdesc_gitrev);
        my $uname_v_gitrev_len = length($uname_v_gitrev);
        if (($pkgdesc_gitrev_len > $uname_v_gitrev_len &&
                substr($pkgdesc_gitrev, 0, $uname_v_gitrev_len) ne $uname_v_gitrev) ||
            ($pkgdesc_gitrev_len <= $uname_v_gitrev_len &&
                $pkgdesc_gitrev ne substr($uname_v_gitrev, 0, $pkgdesc_gitrev_len))) {
            die "Livepatch package GIT rev '$pkgdesc_gitrev' doesn't match '$uname_v_gitrev' from 'uname -v'";
        }
    }

    # Verify that the livepatch module has been properly signed by
    # checking the kernel for TAINT_UNSIGNED_MODULE tainting.
    # TAINT_UNSIGNED_MODULE is represented by bit 13 within the
    # kernel's tainted bitmask.
    if (is_kernel_tainted(0x2000)) {
        die "The kernel has been tainted with TAINT_UNSIGNED_MODULE";
    }
}

1;
