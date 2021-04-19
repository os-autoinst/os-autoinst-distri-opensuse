# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Make installed versions of HPC library packages remain
# installed after migration to new service pack
# Steps: 1.Install previous SP (SLE-HPC text mode profile)
# 2. Make a list of installed packages ('rpm -qa')
# 3. Install all 'library wrappers' (packages matching -hpc, not
#    having a version number with '_' after their name).
# 4. Make a list of installed packages and diff against list from 2.
# 5. From the diff extract the list of HPC library packages (packages
#    matching *-hpc*) with 'underscored' version numbers after the
#    package name) and save this list.
# 6. Perform a migration
# 7. Confirm all packages in the list generated in 5. remain installed.
# Maintainer: Yutao Wang <yuwang@suse.com>

package services::hpcpackage_remain;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use Data::Dumper;
use warnings;

my @diffpkg;

sub list_pkg {
    my ($name) = @_;
    $name //= '';
    my $pkg = script_output("rpm -qa | tee -a /tmp/$name", proceed_on_failure => 1, timeout => 180);
}

sub install_pkg {
    my $version = get_var('HDDVERSION');
    # Install all 'library wrappers' (packages matching -hpc, not having a version number with '_' after their name)
    my @pkginstall = split('\n', script_output q[zypper search -r SLE-Module-HPC] . $version . q[-Pool -r SLE-Module-HPC] . $version . q[-Updates | cut -d '|' -f 2 | sed -e 's/ *//g' | grep -E '.*-hpc.*' | grep -vE 'system|module|suse' |  grep -vE '.*_[[:digit:]]+_[[:digit:]]+.*gnu|.*_[[:digit:]]+_[[:digit:]]+.*-hpc' | grep -vE '.*-static$' | grep -vE '.*hpc-macros.*'], proceed_on_failure => 1, timeout => 180);
    # on x86 zypper will print out the Shell debug information, we need exclude it.
    @pkginstall = grep { !/LMOD_SH_DBG_ON/ } @pkginstall;
    zypper_call("in " . join(' ', @pkginstall), timeout => 1800);
}

sub compare_pkg {
    my ($list1, $list2) = @_;
    $list1 //= '';
    $list2 //= '';
    # Make a list of installed packages and diff against list from installed packages
    @diffpkg = split('\n', script_output("diff $list1 $list2 | grep -E '^>' | cut -d' ' -f2 |  grep -E '.*-hpc.*' |   grep -vE 'system|module|suse' |  grep -E '.*_[[:digit:]]+_[[:digit:]]+.*-gnu|.*_[[:digit:]]+_[[:digit:]]+.*-hpc' |  grep -vE '.*-static\$'", proceed_on_failure => 1, timeout => 180));
}

# The release number needs to be stripped off of the package name
sub del_num {
    my @list = @_;
    my @ls1;
    my $arch = get_var('ARCH');
    foreach my $i (@list) {
        if ($i =~ /$arch|noarch/) {
            my @pkgls = split(/-/, $i);
            pop(@pkgls);
            $i = join('-', @pkgls);
        }
        push @ls1, $i;
    }
    return @ls1;
}

# Confirm all packages in the list generated remain installed
sub check_pkg {
    my @pkglist = split('\n', script_output("rpm -qa", proceed_on_failure => 1, timeout => 180));
    diag "Before migration: " . Dumper(\@diffpkg);
    diag "After migration:" . Dumper(\@pkglist);
    my @after  = del_num(@pkglist);
    my @before = del_num(@diffpkg);
    my %hash_a = map  { $_ => 1 } @after;
    my @b_only = grep { !$hash_a{$_} } @before;
    if (@b_only) {
        die "After migration, some packages are miss: " . Dumper(\@b_only);
    }
}

sub full_pkgcompare_check {
    my (%hash) = @_;
    my $stage = $hash{stage};

    if ($stage eq 'before') {
        list_pkg("orignalq1w2.txt");
        install_pkg();
        list_pkg("installe3r4.txt");
        compare_pkg("/tmp/orignalq1w2.txt", "/tmp/installe3r4.txt");
    }
    else {
        check_pkg;
    }
}

1;
