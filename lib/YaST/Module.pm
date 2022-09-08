# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods that are common for all YaST modules.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Module;
use strict;
use warnings;
use testapi;
use YuiRestClient;
use y2_module_basetest qw(wait_for_exit);
use y2_module_guitest qw(launch_yast2_module_x11);
use y2_module_consoletest qw(yast2_console_exec);

=head2 open

   open(module => $module, ui => $ui);

Unified method to open YaST module while using LibyuiClient. Allows to open the module with both ncurses and Qt UI.
After starting the module ensures that connection to libyui-rest-api server is established.

C<$module> - Module to open. e.g. lan, storage, partitioner etc.
            (full list of available yast2 modules can be observed by running 'yast2 -l' in console);
C<$ui> - User interface the module is expected to be opened with (Possible values: ncurses, qt).

=cut

sub open {
    my %args = @_;
    my $module = $args{module};
    my $ui = lc($args{ui});
    die 'No module name specified.' unless defined $module;
    die 'No user interface specified.' unless defined $ui;
    if ($ui eq 'ncurses') {
        yast2_console_exec(
            yast2_module => $module,
            yast2_opts => '--ncurses',
            extra_vars => get_var('YUI_PARAMS')
        );
    }
    elsif ($ui eq 'qt') {
        launch_yast2_module_x11($module, extra_vars => get_var('YUI_PARAMS'), maximize_window => get_var('MAXIMIZE_WINDOW'));
    }
    else {
        die "Unknown user interface: $ui";
    }
    YuiRestClient::get_app()->check_connection();
}

=head2 close

    close(module => $module, timeout => $timeout);

    Ensure the module has exited by checking with a timeout the serial output.

C<module> module to wait for exit.
C<timeout> timeout to wait on the serial.

=cut

sub close {
    my %args = @_;
    y2_module_basetest::wait_for_exit(module => $args{module}, timeout => $args{timeout});
}

=head2 run_actions

   run_actions(CODEREF, @args)

   Open the module using $args, execute CODEREF and ensure the module has exited
   by checking with a timeout the serial output.

C<$module> - Module to open (i.e.: lan, storage, partitioner).
C<$ui> - User interface to open the module (i.e. : ncurses, qt).
C<$timeout> - timeout to wait on the serial.

=cut

sub run_actions (&@) {
    my $code = \&{shift @_};
    my (%args) = @_;

    YaST::Module::open(module => $args{module}, ui => $args{ui});
    $code->();
    YaST::Module::close(module => $args{module}, timeout => $args{timeout});
}

1;
