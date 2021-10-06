# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
