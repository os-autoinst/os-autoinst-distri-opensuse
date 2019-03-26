# UI Test Automation Framework

## Introduction 

This is the documentation for Object Oriented approach used in automated
UI tests for SUSE products.

## Contents

* [Overview](#overview)
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
     * [Validation Test Module](#validation-test-module)
        * [Test Data usage in Validation Test Module](#test-data-usage-in-validation-test-module)
        * [Access to os-autoinst testapi from Validation Test Module](#access-to-os-autoinst-testapi-from-validation-test-module)
        * [Access to other framework layers from Validation Test Module](#access-to-other-framework-layers-from-validation-test-module)
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


## Overview

The Test Framework is based on
[Page Object Desing Pattern](https://www.seleniumhq.org/docs/06_test_design_considerations.jsp#page-object-design-pattern)
with the certain adaptation related to the environment-specific demands.

It is broken on several [Layers](#framework-layers). The interactions
between the layers could be represented with the following diagram.

![Framework Abstract Diagram](abstract-diagram.png)

main.pm is an entry point for all the tests in openQA, the distribution
is set here with DistributionProvider.

```perl
use testapi;
...
testapi::set_distribution(DistributionProvider->provide());
```

DistributionProvider is a factory that returns the required Distribution
depending on openQA environment variables ('VERSION', 'ARCH', 'BACKEND'
etc.). Currently, Tumbleweed is returned as the default one, following
["Factory First"](https://www.suse.com/documentation/suse-best-practices/singlehtml/sbp-quilting-osc/sbp-quilting-osc.html#sec.factory)
rule.

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

main.pm then calls a scheduled [Test Module](#test-module) that is using
the Distribution to access its components through Controller layer.

>  Important: Test Module must be inherited from opensusebasetest or one
>  of its children to have an access to the Distribution.

```perl
use parent 'opensusebasetest';

sub run {
    my $partitioner = $testapi::distri->get_partitioner_controller();
}
```

## Framework Layers

### Test Module

Test Module is a layer containing test case steps that need to be
executed on the system under test (SUT).

#### Test Data usage in Test Module

All the data for the test should be provided on this level. Do not
provide any test data in [Controller](#controller) or [Page](#page) 
layers.

Example:  

```perl
# Should partitioner enable separate home partition is set in Test Module.
sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal(has_separate_home => 1);
}
```

#### Access to os-autoinst testapi from Test Module

Test Module is not allowed to use os-autoinst testapi functions
directly. It should use methods, provided by [Controller](#controller)
layer instead. This allows to hide the details of the UI structure and
operate with the business logic the system provides.

#### Access to other framework layers from Test Module

Test Module is able to interact only with the Controller layer.

### Controller

Controller is a layer that provides methods to interact with the system
under test in business terms.

#### Test Data usage in Controller

Do not define any test data in [Controller](#controller) layer as it
could make test maintenance more complicated. Use the test data passed
from the [Test Module](#test-module) layer instead.

Example:

* If need to use conditions: 

    ```perl
    sub create_encrypted_partition {
        my ($self, $is_lvm) = @_;
        if ($is_lvm) {
            $self->get_partitioning_scheme_page()->select_lvm_checkbox();
        }
    ...
    }
    ```
* To make an action depending on a value:

  
    ```perl
    sub create_filesystem {
        my ($self, $filesystem) = @_;
        $self->get_filesystem_options_page()->select_filesystem($filesystem);
    ...
    }
    ```
    
#### Access to os-autoinst testapi from Controller

Ideally, it should not use the os-autoinst testapi directly. 

* Do not use testapi methods that communicates with the SUT (e.g.
  `send_keys`, `assert_screen`). Wrap them into [Page](#page) methods
  with the meaningful names instead.

* Using `get_var` to change the flow of a test or get a data for the
  test should be avoided as much as possible (e.g. to decide whether
  check or uncheck checkbox, use method parameters instead and pass the
  data from [Test Module](#test-module).

**NOTE:** Since os-autoinst API does not have separation between methods
for interacting with openQA and interacting with the SUT, the usage of
os-autoinst testapi in [Controller](#controller) layer cannot be fully
avoided at the moment. So, some testapi functions may be used in
exceptional cases.

Example:

It is ok when `get_var` is used in combination with
`record_soft_failure` to just highlight known issue in openQA.

```perl
sub create_encrypted_partition {
...
    if (get_var('SOME_VARIABLE')) {
        record_soft_failure('bsc#1234567');
        return;
    }
...
}
```

#### Access to other framework layers from Controller

It knows only about [Pages](#page) and hides the complexity of
manipulating with them from the [Test Module](#test-module) layer.

However, it also provides access to the [Pages](#page) directly through
the getters. This compromising solution was added for the cases when
specific and rare actions should be made.

Example:
  
For instance, there might be a test, that should create an encrypted
partition. Positive case may use something like:

```perl
sub create_encrypted_partition {
    my ($self) = @_;
    $self->get_partitioning_scheme_page()->select_enable_disk_encryption_checkbox();
    $self->get_partitioning_scheme_page()->enter_password();
    $self->get_partitioning_scheme_page()->enter_password_confirmation();
    $self->get_partitioning_scheme_page()->press_next();
}
```

Then it could be called in all the [Test Modules](#test-module), where 
the encrypted partition need to be created.

```perl
sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->create_encrypted_partition();
}    
``` 

But in case if need to verify some negative cases the method cannot be
used as is. For instance, to verify that prompt appears when blank
password is entered. For such kind of cases the access to the
[Pages](#page) through [Controller](#controller) is added.  
Then [Test Module](#test-module) code may look like:

```perl
sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->get_partitioning_scheme_page()->select_enable_disk_encryption_checkbox();
    $partitioner->get_partitioning_scheme_page()->enter_password('');
    #here assertion for prompt on blank password is performed.
}
```

### Page

Page layer introduces accessing methods to elements of the page/section.

It is not required to describe the accessing methods for all the
elements of a screen in one class. If there is an element or a section
that is common for several pages, it may be extracted into separate
class and then reused by all the pages.

All the page classes (but not the page element or section classes) 
should be inherited from a base page (e.g. in case of pages for
installation wizard, it is Installation::WizardPage).

Unlike the *classic* POM approach, methods of Page layer in the
Framework are not returning Objects. This compromising solution was
introduced because the behavior of SUT may vary depending on the steps,
that were done in the previous Test Modules and also due to a large set
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

### Validation Test Module

Optional layer. The special [Test Module](#test-module) that only makes
sure if the actual state of the SUT corresponds to the expected one.

Useful for validating installation tests, as it is not possible to check
in the installation [Test Module](#test-module), if the changes are 
applied to the system. The system need to be installed first.

#### Test Data usage in Validation Test Module

#### Access to os-autoinst testapi from Validation Test Module

#### Access to other framework layers from Validation Test Module

* If the validation should be made via UI, consider this layer as the 
  regular [Test Module](#test-module) with all the appropriate conventions, like
  accessing to the page through [Controller](#controller) only.
* For console tests, there is no strict rules as of now. Use testapi
  directly.

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
    my $user_settings_widget = $testapi::distri->get_user_settings_widget();
    $user_settings_widget->create_user({
                  username       => 'test_user', 
                  user_full_name => 'Test User Full Name'
                  });
}

1;

```

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
  first'rule.
  
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
  
### 5. Add a test module to scheduling file.
In order to run the Test Module, it should be added to the scheduling
file (e.g. main.pm)

```perl
 ...
 loadtest 'installation/create_new_user';
 ...
```