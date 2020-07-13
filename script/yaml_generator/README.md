# YAML Generator for openQA Jobs

The generator allows to create YAML schedule file using Job ID from openQA.

## System Requirements

Python 3.8 or later

## Setup

Create [virtualenv](https://packaging.python.org/guides/installing-using-pip-and-virtual-environments/#creating-a-virtual-environment) 
and activate it

```shell script
cd script/yaml_generator/
python3 -m venv env
source env/bin/activate
```

Install required packages with pip using requirements.txt
```shell script
pip install -r requirements.txt
```

## Usage

```shell script
python3 create_scheduler.py <jobid> <path_to_save> [<openqa_server>]
```

This will generate the <path_to_save>/template.yaml

Example:
```shell script
python3 create_scheduler.py 1 /tmp
```
or
```shell script
python3 create_scheduler.py 1 /tmp openqa.opensuse.org
```

If openqa_server is not given, OSD is used by default.
All the params are positional.

Content of the generated template.yaml:
- name
- description
- vars
- schedule

openQA variables are taken from the test suite variables.

## Issues to address

- Some environment variables are not translated. For example:
```shell script
PUBLISH_HDD_1: SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-unregistered.qcow2
``` 
- TODO: path should be setup to point to the schedule dir by default 
- TODO: variables from a file
