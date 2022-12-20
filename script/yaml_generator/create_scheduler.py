import requests
import sys, os
from openqa_client.client import OpenQA_Client
from pathlib import Path
import re
import yaml


class MyDumper(yaml.Dumper):
    def increase_indent(self, flow = False, indentless = False):
        return super(MyDumper, self).increase_indent(flow, False)

    
def _get_scheduling(jobid, srv):
    testpage = 'https://%s/tests/%s/file/autoinst-log.txt' % (srv, jobid)
    ctx = requests.get(testpage, verify=False)
    regex = re.compile('scheduling\s\w+\stests\/\w+\/\w+\/?\w*')
    matches = regex.findall(repr(ctx.content))
    key = 'tests/'
    job = []
    for schedule_line in matches:
        schedule = schedule_line[schedule_line.find(key)+len(key):]
        job.append(schedule)
    return job


def _get_conf(jobid, srv):
    client = OpenQA_Client(server='http://%s' % srv)
    conf = client.openqa_request('GET', 'jobs/%s' % jobid)

    testname = conf['job']['settings']['TEST_SUITE_NAME']
    jobvars = {}
    jobvars['name'] = testname
    suitevars = client.openqa_request('GET', 'test_suites')

    vars_generator = (settings for settings in suitevars['TestSuites'])

    for v in vars_generator:
        if testname == v.get('name'):
            jobvars.update(v)
            break
    return jobvars


def _create_template(scheduling, configs, save_to):
    # there are jobs come back from /test_suites without description
    if 'description' in configs.keys():
        description = configs['description'].replace('\n', '')
    else:
        description = ""
    
    data = {'name': configs['name'],
            'description': "|\n%s" % description}

    if configs:
        data['vars'] = {}
        data['vars'].update({k['key']:k['value'] for k in configs['settings']})
    data['schedule'] = scheduling
    # TODO path configuration
    out = Path(os.path.abspath(os.path.join(save_to, 'template.yaml')))

    with(open(out, 'w')) as out:
        yaml.dump(data,
                  stream=out,
                  default_flow_style=False,
                  Dumper=MyDumper,
                  explicit_start=True,
                  sort_keys=False)


if __name__ == '__main__':
    jobid = sys.argv[1]
    save_to = sys.argv[2]
    openqa_server = sys.argv[3] if len(sys.argv) > 3  else 'openqa.suse.de'
    schd = _get_scheduling(jobid, openqa_server)
    conf = _get_conf(jobid, openqa_server)
    _create_template(schd, conf, save_to)
