# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
package grub_utils;

use testapi;
use base 'Exporter';
use Exporter;
use version_utils qw(is_jeos);

BEGIN {
    our @EXPORT = qw(
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
}

use constant GRUB_CFG_FILE     => "/boot/grub2/grub.cfg";
use constant GRUB_DEFAULT_FILE => "/etc/default/grub";

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

    grep_grub_cmdline_settings($pattern)

Search for C<$pattern> in grub cmdline variable (usually
GRUB_CMDLINE_LINUX_DEFAULT) in /etc/default/grub, return 1 if found.
=cut
sub grep_grub_cmdline_settings {
    my $pattern = shift;
    return grep_grub_settings(get_cmdline_var() . ".*${pattern}");
}

=head2 change_grub_config

    change_grub_config($old, $new [, $search ] [, $modifiers ]);

Replace $old with $new in /etc/default/grub, using sed.
C<$search> meant to be for changing only particular line for sed,
C<$modifiers> for sed replacement, e.g. "g".
=cut
sub change_grub_config {
    die((caller(0))[3] . ' expects from 2 to 4 arguments') unless (@_ >= 2 || @_ <= 4);
    my ($old, $new, $search, $modifiers) = @_;
    $search = "/$search/" if defined $search;

    assert_script_run("sed -ie '${search}s/${old}/${new}/${params}' " . GRUB_DEFAULT_FILE);
}

=head2 add_grub_cmdline_settings

    add_grub_cmdline_settings($add);

Add $add into /etc/default/grub, using sed.
=cut
sub add_grub_cmdline_settings {
    my $add = shift;

    change_grub_config('"$', " $add\"", get_cmdline_var(), "g");
}

=head2 replace_grub_cmdline_settings

    replace_grub_cmdline_settings($old, $new);

Replace $old with $new in /etc/default/grub, using sed.
=cut
sub replace_grub_cmdline_settings {
    my ($old, $new) = @_;

    change_grub_config($old, $new, get_cmdline_var(), "g");
}

=head2 remove_grub_cmdline_settings

    remove_grub_cmdline_settings($remove);

Remove $remove from /etc/default/grub (using sed) and regenerate /boot/grub2/grub.cfg.
=cut
sub remove_grub_cmdline_settings {
    my $remove = shift;
    replace_grub_cmdline_settings('[[:blank:]]*' . $remove . '[[:blank:]]*', "", "g");
}

=head2 grub_mkconfig

    grub_mkconfig();

Regenerate /boot/grub2/grub.cfg with grub2-mkconfig.
=cut
sub grub_mkconfig {
    assert_script_run('grub2-mkconfig -o ' . GRUB_CFG_FILE);
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

1;
# vim: sw=4 et
