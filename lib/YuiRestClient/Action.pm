# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Action;

use strict;
use warnings;

use constant {
    YUI_PRESS      => 'press',
    YUI_TOGGLE     => 'toggle',
    YUI_CHECK      => 'check',
    YUI_UNCHECK    => 'uncheck',
    YUI_SELECT     => 'select',
    YUI_ENTER_TEXT => 'enter_text'
};

1;
