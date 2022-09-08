# UI Test Automation Framework

## Introduction 

This is the documentation for Object Oriented approach used in automated GUI testing for (Open)SUSE products.

## Contents

* [Context](#context)
* [Overview](#overview)
  * [Definition of the product to be tested](#definition-of-the-product-to-be-tested)
  * [Definition of the workflow according to the product](#definition-of-the-workflow-according-to-the-product)
  * [Framework Layers](#framework-layers)
     * [Test Module](#test-module)
        * [Test Data usage in Test Module](#test-data-usage-in-test-module)
        * [Access to os-autoinst testapi from Test Module](#access-to-os-autoinst-testapi-from-test-module)
        * [Access to other framework layers from Test Module](#access-to-other-framework-layers-from-test-module)
     * [Controller](#controller)
        * [Test Data usage in Controller](#test-data-usage-in-controller)
        * [Access to os-autoinst testapi from Controller](#access-to-os-autoinst-testapi-from-controller)
        * [Access to other framework layers from Controller](#access-to-other-framework-layers-from-controller)
     * [Page](#page)
        * [Test Data usage in Page](#test-data-usage-in-page)
        * [Access to os-autoinst testapi from Page](#access-to-os-autoinst-testapi-from-page)
        * [Access to other framework layers from Page](#access-to-other-framework-layers-from-page)
  * [Style Guide](#style-guide)
     * [Naming Conventions](#naming-conventions)
        * [Identifiers](#identifiers)
        * [Booleans](#booleans)
     * [Named Arguments in Methods](#named-arguments-in-methods)
  * [Getting Started](#getting-started)
     * [1. Create a Test Module with the steps.](#1-create-a-test-module-with-the-steps)
     * [2. Define the steps in Controller.](#2-define-the-steps-in-controller)
     * [3. Specify actions provided by the Page;](#3-specify-actions-provided-by-the-page)
     * [4. Add a method to get the Controller to the required Distribution.](#4-add-a-method-to-get-the-controller-to-the-required-distribution)
     * [5. Add a test module to scheduling file.](#5-add-a-test-module-to-scheduling-file)
   
## Context

SUSE Products changes and evolves across versions, and we are expected to write tests for various versions of the same product. However, we may still want to re-use the same [business
logic](https://en.wikipedia.org/wiki/Business_logic) and avoid to write different code for each specific case.

Throughout the course of the project history, we attempted to solve this issue with many approaches; in the following order:


-  The *"naive"* way: leads to dealing with a lot of if-else conditions [*"Spaghetti Code"*](https://en.wikipedia.org/wiki/Spaghetti_code) with things like ```if (is_food AND (is_a_banana OR ! is_a_fruit))``` while it's intuitive to write, and the inner logic of test differentiation is directly modeled in the code, it can be exhausting to read and maintain as the conditions sum-up over time, and therefore should be avoided.

- Passing variables from outside ([external test data](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md#test_data)): tests are still written in a generic way but with a *Data Driven* design. This solution is simpler than the previous, but still complex, as the number of variable combinations increases exponentially, and leads to increase difficulty on debugging and understanding the control flow of the program. Consider also that OpenQA variables can be defined at many levels: medium, job group, schedule, command line...etc. And by looking at a job result it's not always clear where a variable comes from.

- Very simple modules doing only one specific task, with schedules adapted for each case. Variables (test data) are passed from the test module to some libraries __only if needed__. The schedule is used to handle the various scenarios rather than conditions in the code, and the name of the module accurately describes what it does. As the number of special situations grows, use inheritance and interchangeable test data to simplify the code while maintaining backward compatibility. With the combined usage of [declarative scheduling](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md) we obtain certain advantages: code is straightforward to write, understand, and debug, while the complexity is partially shifted to the YAML schedule. We accept the trade-off of an increased number of (simple) modules to build and maintain, also because the development work can be evenly distributed across the team.

In the following guide let's explain in detail the last solution.

## Overview

The framework proposed here is based on
[Page Object Desing Pattern](https://www.selenium.dev/documentation/en/guidelines_and_recommendations/page_object_models/),
implemented using ["Old school" object-oriented perl](https://www.perl.com/article/25/2013/5/20/Old-School-Object-Oriented-Perl/)
with a certain adaptation related to the environment-specific demands.

It is broken on several [Layers](#framework-layers). The interactions
between the layers could be represented with the following diagram.

![Framework Abstract Diagram](abstract-diagram.png)

### Definition of the product to be tested

main.pm is an entry point for all the tests in openQA, the distribution
is set here with DistributionProvider.

```perl
use testapi;
...
testapi::set_distribution(DistributionProvider->provide());
```

DistributionProvider (lib/DistrubutionProvider.pm) is a 
[factory](https://en.wikipedia.org/wiki/Factory_%28object-oriented_programming%29) that returns the required 
"distribution" depending on openQA environment variables ('VERSION', 'DISTRI'). Currently, Tumbleweed is returned as 
the default one if none specified, following
["Factory First"](https://opensource.suse.com/suse-open-source-policy#factory-first) rule.

```perl
package DistributionProvider;
...
sub provide {
    return Distribution::Sle::15->new()            if version_utils::is_sle('15+');
    return Distribution::Sle::12->new()            if version_utils::is_sle('12+');
    return Distribution::Opensuse::Leap::15->new() if version_utils::is_leap('15.0+');
    return Distribution::Opensuse::Leap::42->new() if version_utils::is_leap('42.0+');
    return Distribution::Opensuse::Tumbleweed->new();
}
```
Each product has its class under lib/Distribution. The parent class is Tumbleweed.pm, as all other products are derived 
from it, so what works on TW usually works everywhere else. When it is not the case, a specific method can be created
in the appropriate Distribution class in lib/Distribution:

```perl
.
├── Opensuse
│   ├── Leap
│   │ ├── 15.pm
│   │ └── 42.pm
│   └── Tumbleweed.pm
└── Sle
├── 12.pm
├── 15_current.pm
├── 15sp0.pm
└── 15sp2.pm
```

### Definition of the workflow according to the product

main.pm calls a scheduled [Test Module](#test-module) using 
[declarative scheduling](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md)
(please don't schedule modules in main*.pm directly !), the module uses the 
[factory](https://en.wikipedia.org/wiki/Factory_%28object-oriented_programming%29)
in DistributionProvider to determine what product version we are using, then the Distribution file (eg 12.pm)
determines what business logic applies for this distribution, so in practice, what [controller](#controller) 
has to be used:

>  Important: Test Module must be inherited from opensusebasetest or one
>  of its children to have an access to the Distribution.
```perl
# Test module

use parent 'opensusebasetest';

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->some_method_defined_in_controller();
}
```
The method get_partitioner calls the right controller according to the product version,
eg for Tumbleweed:


```perl
package Distribution::Opensuse::Tumbleweed;
use Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController;

sub get_expert_partitioner {
    return Installation::Partitioner::LibstorageNG::v4_3::ExpertPartitionerController->new();
}
```
In this example, the path to the proper partitioner's controller for Tumbleweed is 
```libsorageNG/v4.3/ExpertPartitionerController.pm```. The class "ExpertPartitionerController"
re-uses common parts from older versions of the product.
```
.
├── ExpertPartitionerPage.pm                   # Base page class used by ExpertPartitionerController
├── FormattingOptionsPage.pm                   # Another page that can also be used by the controller
├── Libstorage
│   ├── ExpertPartitionerController.pm         # libstorage (and base) controller class. Calls methods from the page(s)
├── LibstorageNG
│   ├── ExpertPartitionerPage.pm               # Page class common to v3 and v4, derived from the base page class.
│   ├── v3
│   │   └── ExpertPartitionerController.pm     # Controller class derived from libstorage
│   ├── v4
│   │   └── ExpertPartitionerController.pm     # Controller class derived from v3
│   └── v4_3
│       ├── ExpertPartitionerController.pm     # Controller class derived from v4, used here for Tumbleweed.
│       ├── ExpertPartitionerPage.pm           # Page class derived from LibstorageNG v3/4
```
* Note: The example is taken from a real case, libstorage was the "expert partitioner" for SLE12 / Leap 42, it was 
  re-written and called libstorage-ng to become the default for the next product versions, and then it kept evolving. 
  This model proved to be adaptive and backward-compatible in such context, we can still
  schedule a same test module on both SLE12 and the latest Tumbleweed, without any conditions in the code: we just need 
  to adjust the test data and maybe some needles. 

## Framework Layers

Abstract: All direct interactions with the GUI are defined in a [page](#page), those methods are grouped in higher-level methods 
 within a [controller](#controller) to form 
"[business
logic](https://en.wikipedia.org/wiki/Business_logic)" actions, and the methods from the controller are called from a
[test module](#test-module).
* Note: The page-object model only applies to interactions with GUI, so any interaction with the
  command-line can take place directly in the test module and use testapi
  directly. But the use of [declarative scheduling](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md)
  and [external test data](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md#test_data)
  should always be considered in order to avoid "spaghetti code".

### Test Module

Test Module is a layer containing test case steps that need to be
executed on the system under test (SUT).

 The variables to be used in the test are defined here before being passed to the other layers.
In our test module, we should not care about the specifics of each SUT. If we want to format some disks,
 We may create a method called ```format_disks```, defined in a [controller](#controller), that can be re-used 
in all variants of products. It should describe a [business
logic](https://en.wikipedia.org/wiki/Business_logic) workflow, using a verb and a business-logic object (examples:
 select_dynamic_address_for_ethernet, create_encrypted_partition).
Instead of adding conditions in the module, we should use different [test data](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md#test_data)
 for each specific case and create some sub-classes ([page](page) and/or [controller](controller)) for each specific workflow where needed.

#### Test Data usage in Test Module

All the test data should be provided at this level, preferably not hard-coded.
Do not provide any test data in [Controller](#controller) or [Page](#page)
layers. 

Example with hard-coded test data:


```perl
# Should partitioner enable separate home partition is set in Test Module.
sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal(has_separate_home => 1);
}
```

Or if we are using [external test data](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md#test_data) (recommended)

```perl
sub run {
    my $test_data = get_test_suite_data()
    my $partitioner = $testapi::distri->get_partitioner();
    
    foreach my $partition (@{test_data->{partitions}) { $partitioner->partition_disk($partition) }
}
 ```
#### Access to os-autoinst testapi from Test Module

Test Module is not allowed to use os-autoinst testapi functions
directly. It should use methods, provided by [Controller](#controller)
layer instead. This allows to hide the details of the UI structure and
operate with the [business
logic](https://en.wikipedia.org/wiki/Business_logic) the system provides.

This being said, for logging purposes, "diag", "record_info" or "save_screenshot", "record_soft_failure" can be used
in the test module when it cannot be done at the page level.

#### Access to other framework layers from Test Module

Test Module is able to interact only with the Controller layer.

### Controller

The controller is a layer that provides methods to interact with the system
under test in [business](https://en.wikipedia.org/wiki/Business_logic) terms. Those methods combine together lower-level methods
from the page layer, and are used by
the test modules.

Example:

For instance, there might be a test, that should create an encrypted
partition. In this example, methods such as "enter_password" are defined in the [page](#page).

```perl
sub create_encrypted_partition {
    my ($self) = @_;
    $self->get_partitioning_scheme_page()->select_enable_disk_encryption_checkbox();
    $self->get_partitioning_scheme_page()->enter_password();
    $self->get_partitioning_scheme_page()->enter_password_confirmation();
    $self->get_partitioning_scheme_page()->press_next();
}
```

Then it is called in all the [Test Modules](#test-module), where
the encrypted partition needs to be created.

```perl
sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->create_encrypted_partition();
}    
``` 

#### Test Data usage in Controller

Do not define any test data in [Controller](#controller) layer as it
could make test maintenance more complicated. Use the test data passed
from the [Test Module](#test-module) layer instead.

As everywhere else, avoid conditions in general as much as possible. Try instead to create another appropriate
[business-logic](https://en.wikipedia.org/wiki/Business_logic) method
and/or think how to organize the test data according to what is expected.

Example:


To make an action depending on a variable, we could do something like this:

```perl
sub create_encrypted_partition {
    my ($self, $args) = @_;
    if ($args->{is_lvm}) {
        $self->get_partitioning_scheme_page()->select_lvm_checkbox();
    }
    [...]
    $self->get_expert_partitioner_page()->press_next()
}
```
But a better way is probably to create an appropriate method:

```perl
sub create_encrypted_lvm_partition {
    my ($self, $args) = @_;
    $self->get_partitioning_scheme_page()->select_lvm_checkbox();
    [...]
    $self->get_expert_partitioner_page()->press_next()
}
```
If you need to use a variable, you can define it in the test data and pass it as follows from the test module:

```perl
sub create_filesystem {
    my ($self, $args) = @_;
    $self->get_filesystem_options_page()->select_filesystem($args->{filesystem});
    $self->get_expert_partitioner_page()->press_next()
}
```


#### Access to os-autoinst testapi from Controller

* Do not use testapi methods that communicates with the SUT (e.g.
  `send_keys`, `assert_screen`). Wrap them into [Page](#page) methods
  with the meaningful names instead.

* Using `get_var` to change the flow of a test or get a data for the
  test should be avoided as much as possible (e.g. to decide whether
  check or uncheck checkbox, use method parameters instead and pass the
  data from [Test Module](#test-module)).
  
* Local libs from os-autoins-distri-opensuse should not be used here either, but rather in the test module.

* "diag", "record_info" or "save_screenshot", "record_soft_failure" could be used here, as this does not change the 
  test flow, since it is just used for logging. But consider to put it in the module or page instead.

#### Access to other framework layers from Controller

It knows only about [Pages](#page) and is called by the [Test Module](#test-module).

### Page

The page layer is where the direct interactions with the UI (like pressing a button) take place, so here we
can use testapi.
The layer introduces accessing methods to elements of the page, or section of the page.

All the page classes (but not the page element or section classes) 
can inherit from a base page (e.g. in case of pages for
installation wizard, it is Installation::WizardPage).
If some elements or sections are common for several pages 
(like OK/Cancel buttons in a wizard) the corresponding 
accessing methods may be written in this base page or in a separate class,
to be used by all other pages.

Unlike the *classic* POM approach, methods of Page layer in the
Framework are not returning Objects. This compromise was
introduced because the behavior of SUT may vary depending on the steps,
that were done in the previous test Modules and also due to a large set
of versions, which behavior also may differs.

Example:   
```perl
package Installation::Partitioner::Libstorage::PasswordDialog;

sub press_ok {
    assert_screen(ENTER_PASSWORD_DIALOG);
    send_key('alt-o');
}
```

#### Test Data usage in Page

Do not provide any test data in [Page](#page) layer. Use the test data
passed from the [Test Module](#test-module) layer instead.

#### Access to os-autoinst testapi from Page

This is the only layer having full access to testapi.

>  NOTE: Using `get_var` or similar methods to change the flow of a test
>  should be avoided (e.g. to decide whether select checkbox or not by
>  checking openQA variable. Please, use method parameters instead).

#### Access to other framework layers from Page

It should not use methods of another layers. It just provides page
accessing methods for [Controller](#controller) layer.

## Style Guide

### Naming Conventions

#### Identifiers

* Package and Class names should be nouns, using mixed case with the
  first letter of each word capitalized.

  Example:
  ```perl
  package Installation::Partitioner::Libstorage::EditProposalSettingsController;
  ```
* Method names should be verbs, using lowercase with the underscores
  between the words.
  
  Example:
  ```perl
  sub get_password_dialog;

  sub edit_proposal;
  ```
* Variable names should be lowercase with the underscores between the
  words.
  
  Example:
  ```perl
  my $is_lvm;
  my $filesystem;
  ```
  
* Constant names should be uppercase with the underscores between the
  words.
  
  Example:
  ```perl
  use constant {
      SUGGESTED_PARTITIONING_PAGE                  => 'inst-suggested-partitioning-step',
      LVM_ENCRYPTED_PARTITION_IN_LIST              => 'partitioning-encrypt-activated'
  };
  ``` 
  
* Methods in the controllers should describe a business-logic action using a verb and business-logic object 
  (examples: _create_encrypted_partition_ or_select_dynamic_address_for_ethernet_). Those should not be things like
  "select_this_button" as those functions should be in pages.
  
#### Booleans

* Methods returning true/false or variables that store them, should be
  named beginning with is_ or has_.
  
  Example:
  ```perl
  sub is_lvm;
  sub has_separate_home;  
  
  my $is_checkbox_checked;  
  my $has_license_agreement;
  ```   
  
* Note: such methods should be defined only in pages
  
### Named Arguments in Methods

Use named arguments in hash reference if Method has more than one 
argument.

Example:
```perl
sub edit_proposal {
    ($self, $args_ref) = @;
    my $is_lvm = $args_ref->{is_lvm};
    my $has_separate_home = $args_ref->{has_separate_home};
    ...
}

# Then usage:

 edit_proposal({is_lvm => 1, has_separate_home => 1});
``` 

### Abbreviated prefixes for YuiRestClient widgets

To avoid confusion identifiers that refer to UI widgets should be prefixed with a three-letter abbreviation for the widget followed by an underscore '_'.

**Building rules for prefixes**

* prefixes have the length of 3 letters, all in lower case
* all letters are consonants, except you have not enough, then take vowels as well (e.g. the Tab widget transforms to 'tab')
* if a widget name consists of 2 words in CamelCase type style then the first two characters come from the first word, the 3rd character from the second word
* avoid repetition of the same letter, therefore it is "btn" for Button and not "btt"

Applying the rules above gives us the following prefixes:

| Prefix | Widget | Example     |
|--------|--------|-------------|
| btn    | Button | btn_ok      |
| chb    | CheckBox | chb_autologin |
| cmb    | ComboBox | cmb_filesystem |
| its    | ItemSelector | its_keyboard_layout |
| lbl    | Label   | lbl_warning | 
| mnc    | MenuCollection | mnc_operation |
| prb    | ProgressBar | prb_total_packages |
| rdb     | RadioButton | rdb_skip_registration |
| rct     | RichText    | rct_welcome |
| slb   | SelectionBox | slb_addons | 
| tbl    | Table        | tbl_devices |
| txb    | TextBox      | txb_maximum_channel | 
| tre   | Tree         | tre_system_view |
| tab    | Tab          | tab_boot_loader_settings |



## Getting Started

So, basically a new test requires to have at least one package/class per
each layer to be created (or updated if the required class already
exists).

Let's assume there might be a new test to create an account in the
system during installation.

### 1. Create a Test Module with the steps.

{project_root}/tests/installation/create_account.pm
```perl
use strict;
use warnings;
use parent "installbasetest";

sub run {
    my $test_data = get_test_suite_data();
    my $user_settings_widget = $testapi::distri->get_user_settings_widget();
    $user_settings_widget->create_user({
                  username       => $test_data->{username}, 
                  user_full_name => $test_data->{user_full_name}
                  });
}

1;

```
In the module we do not know how to "create an account", as it may vary across products. The most important
here is to set clear expectations and create a data structure accordingly.
In this case we could create a very simple test data file containing:

```yaml
  username: frankie
  user_full_name: "Frank Einstein"
```

* tip: Obviously this is a very simple data structure. if something more complex is needed, it can be helpful to use
Data::Dumper to verify that the structure gets interpreted as per our expectations.

### 2. Define the steps in Controller.

{project_root}/lib/Installation/UserSettingsController.pm
```perl
package Installation::UserSettingsController
use strict;
use warnings;
use parent 'Installation::WizardPage';

use Installation::UserSettingsPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        user_settings_page => Installation::UserSettingsPage
    }, $class;
}

sub get_user_settings_page {
    my ($self) = @_;
    return $self->{user_settings_page};

sub create_user {
    my ($self, $args_ref) = @_;
    my $username = $args_ref->{username};
    my $user_full_name = $args_ref->{user_full_name};
    get_user_settings_page()->fill_in_username($username);
    get_user_settings_page()->fill_in_user_full_name($user_full_name);
    get_user_settings_page()->fill_in_password();
    get_user_settings_page()->fill_in_password_confirmation();
    get_user_settings_page()->press_next();
}

1;

```

### 3. Specify actions provided by the Page;

{project_root}/lib/Installation/UserSettingsPage.pm
```perl
package Installation::UserSettingsPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::WizardPage';

use constant {
    # The needle to represent the page (e.g. Title in Installation Wizard). It is used to make sure that 
    # action is performed on the right Page.
    USER_SETTINGS_PAGE => 'user-settings-page' 
};

sub fill_in_username {
    my ($self, $username) = @_;
    assert_screen(USER_SETTINGS_PAGE);   # ensure the correct Page is shown before performing an action
    send_key('alt-u');                   # make the field to be in focus
    type_string($username);              # type the username
}

sub fill_in_user_full_name {
    my ($self, $user_full_name) = @_;
    assert_screen(USER_SETTINGS_PAGE);   # ensure the correct Page is shown before performing an action
    send_key('alt-f');                   # make the field to be in focus
    type_string($user_full_name);        # type the User's Full Name
}

sub fill_in_password {
    assert_screen(USER_SETTINGS_PAGE);   # ensure the correct Page is shown before performing an action
    send_key('alt-p');                   # make the field to be in focus
    type_password();                     # testapi method to enter the default secret password
}

sub fill_in_password_confirmation {
    assert_screen(USER_SETTINGS_PAGE);   # ensure the correct Page is shown before performing an action
    send_key('alt-o');                   # make the field to be in focus
    type_password();                     # testapi method to enter the default secret password
}

# overrides parent 'Installation::WizardPage' method.
sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(USER_SETTINGS_PAGE);
}

1;

```

### 4. Add a method to get the Controller to the required Distribution.

* Let's assume all the distributions have the same implementation of the
  User Settings. Then add the controller to Tumbleweed distribution, as
  all other distributions are inherited from it to follow 'factory
  first' rule.
  
  {project_root}/lib/Distribution/Opensuse/Tumbleweed.pm
  ```perl
    package Distribution::Opensuse::Tumbleweed;
    use strict;
    use warnings FATAL => 'all';
    use parent 'susedistribution';
    use Installation::UserSettingsController;
    
    sub get_user_settings {
        return Installation::UserSettingsController->new();
    }
    
    1;

  ```
* If some of the Distributions has different implementation of User
  Settings for the same feature. For example, it still allows to create
  new user, but with different steps.
  
  In this case, just override the `get_user_settings` method in the
  required Distribution.
  
  ```perl
  package Distribution::Opensuse::Leap::42;
  use strict;
  use warnings FATAL => 'all';
  use parent 'Distribution::Sle::12';
  
  sub get_user_settings {
          return Installation::SomeAnotherImplementationOfUserSettingsController->new();
      }
  
  1;
  ```
  
### 5. Add the test module to scheduling file.
In order to run the Test Module, it should be added to a [scheduling
file](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/declarative-schedule-doc.md). Please,
do not add spaghetti code in main*.pm !

```yaml
---
name: Incredible test suite
description: >
  Do incredible things
schedule:
  [...]
  - installation/create_account
  [...]
```
