# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods that are common for all YaST modules.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Module;
use strict;
use warnings;
use testapi;
use YuiRestClient;
use y2_module_guitest qw(launch_yast2_module_x11);
use y2_module_consoletest qw(yast2_console_exec);

=head2 open($args)

   open(module => $module, ui => $ui);

Unified method to open YaST module while using LibyuiClient. Allows to open the module with both ncurses and Qt UI.
After starting the module ensures that connection to libyui-rest-api server is established.

C<$module> - Module to open. e.g. lan, storage, partitioner etc.
            (full list of available yast2 modules can be observed by running 'yast2 -l' in console);
C<$ui> - User interface the module is expected to be opened with (Possible values: ncurses, qt).

=cut

sub open {
    my ($args) = @_;
    my $module = $args->{module};
    my $ui     = lc($args->{ui});
    die 'No module name specified.'    unless defined $module;
    die 'No user interface specified.' unless defined $ui;
    if ($ui eq 'ncurses') {
        yast2_console_exec(
            yast2_module => $module,
            yast2_opts   => '--ncurses',
            extra_vars   => get_var('YUI_PARAMS')
        );
    }
    elsif ($ui eq 'qt') {
        launch_yast2_module_x11($module, extra_vars => get_var('YUI_PARAMS'));
    }
    else {
        die "Unknown user interface: $ui";
    }
    YuiRestClient::connect_to_app_running_system();
}

1;
