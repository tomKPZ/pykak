#! /usr/bin/env python3

import argparse
import textwrap
import sys


parser = argparse.ArgumentParser('pykak server')
parser.add_argument('kak2py', type=str)
parser.add_argument('py2kak', type=str)
args = parser.parse_args()


def reply(response):
    # TODO: Fix this deadlock
    import time
    time.sleep(0.01)
    with open(args.py2kak, 'w') as f:
        f.write(response)


while True:
    with open(args.kak2py, 'r') as f:
        request = textwrap.dedent(f.read())
    exec(request)
    reply('fail "end of request"')
