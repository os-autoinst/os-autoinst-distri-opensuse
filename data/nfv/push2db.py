#!/usr/bin/python2

import argparse
import csv
import requests
import logging
import re
import os

def parse_csv(parsefile, os_version, os_build, vswitch_version, openqa_url):
    with open(parsefile, 'rb') as csvfile:
        csvreader = csv.DictReader(csvfile, delimiter=',')
        for row in csvreader:
            request_string = 'throughput,'
            request_string += (
                'tx_frames={0},'
                'rx_frames={1},'
                'tx_rate_fps={2},'
                'throughput_rx_fps={3},'
                'tx_rate_mbps={4},'
                'throughput_rx_mbps={5},'
                'frame_loss_percent={6},'
                'min_latency_ns={7},'
                'max_latency_ns={8},'
                'avg_latency_ns={9},'
                'type={10},'
                'packet_size={11},'
                'id={12},'
                'deployment={13},'
                'vswitch={14},'
                'traffic_type={15},'
                'test_execution_time={16},').format(
                row['tx_frames'],
                row['rx_frames'],
                row['tx_rate_fps'],
                row['throughput_rx_fps'],
                row['tx_rate_mbps'],
                row['throughput_rx_mbps'],
                row['frame_loss_percent'],
                row['min_latency_ns'],
                row['max_latency_ns'],
                row['avg_latency_ns'],
                row['type'],
                row['packet_size'],
                row['id'],
                row['deployment'],
                row['vswitch'],
                row['traffic_type'],
                row['test_execution_time'])
            request_string += (
                'os_version={0},'
                'os_build={1},'
                'openqa_url={2},'
                'vswitch_version={3}').format(
                os_version,
                os_build,
                openqa_url,
                vswitch_version)
            request_string += ' value={0}'.format(row['throughput_rx_mbps'])

            logging.info('Posting data - {0}'.format(request_string))
            response = requests.post(url, data=request_string)
            logging.info('Response from DB: {0}'.format(response.content))


logging.basicConfig(filename='push2db.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console.setFormatter(formatter)
logging.getLogger('').addHandler(console)

parser = argparse.ArgumentParser()
parser.add_argument('--parsefile')
parser.add_argument('--parsefolder', default='/tmp')
parser.add_argument('--targeturl', default='http://fromm.arch.suse.de:8086')
parser.add_argument('--os_version')
parser.add_argument('--os_build')
parser.add_argument('--vswitch_version')
parser.add_argument('--openqa_url')
args = parser.parse_args()

url = args.targeturl + '/write?db=nfv_perf_data'

if args.parsefile:
    logging.info('Starting export. parserfile={0} targeturl={1}'
                 .format(args.parsefile, args.targeturl))
    parse_csv(args.parsefile, args.os_version, args.os_build,
              args.vswitch_version, args.openqa_url)
elif args.parsefolder:
    R = re.compile('results_.*')
    result_folders_list = [folder for folder in os.listdir(
        args.parsefolder) if R.match(folder)]
    for result_folder in result_folders_list:
        result_folder = os.path.join(args.parsefolder, result_folder)
        for file in os.listdir(result_folder):
            if file.endswith(".csv"):
                parsefile = os.path.join(args.parsefolder, result_folder, file)
        logging.info('Parsing file {0}'.format(parsefile))
        parse_csv(parsefile, args.os_version, args.os_build,
                  args.vswitch_version, args.openqa_url)
else:
    raise Exception('specify parsefolder or parsefile param')
