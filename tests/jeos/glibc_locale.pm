# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module tests glibc-locale
# Maintainer: Ciprian Cret <ccret@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use version_utils qw(is_opensuse is_sle is_jeos);

sub run {
    my (%args) = @_;

    zypper_call('in glibc-locale');
    my $locale = get_var('JEOSINSTLANG', 'en_US');
    my $output = script_output("localectl list-locales | grep $locale.utf8");

    die "Test locale not found in the available ones" unless ($output =~ $locale);

    assert_script_run("localectl set-locale LANG=$locale.UTF-8");
    assert_script_run("export LC_ALL='$locale.UTF-8'");

    my $user = $args{user_is_root};
    my $lang = get_var('JEOSINSTLANG', 'en_US');

    my %tz_data = ('en_US' => 'UTC', 'de_DE' => 'Europe/Berlin');
    assert_script_run("timedatectl set-timezone " . $tz_data{$lang});
    assert_script_run("timedatectl | awk '\$1 ~ /Time/ { print \$3 }' | grep ^" . $tz_data{$lang} . "\$");

    my %locale_data = ('en_US' => 'en_US.UTF-8', 'de_DE' => 'de_DE.UTF-8');
    assert_script_run("locale | tr -d \\'\\\" | awk -F= '\$1 ~ /LC_CTYPE/ { print \$2 }' | grep ^" . $locale_data{$lang} . "\$");

    my %lang_data = ('en_US' => 'For bug reporting', 'de_DE' => 'Eine Anleitung zum Melden');
    my $proglang = $args{user_is_root} ? 'en_US' : $lang;
    assert_script_run("ldd --help | grep '^" . $lang_data{$proglang} . "'");

}

1;
