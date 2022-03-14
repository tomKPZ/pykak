#! /usr/bin/env python3

import argparse
import itertools
import textwrap
import sys


parser = argparse.ArgumentParser('pykak server')
parser.add_argument('kak2pya', type=str)
parser.add_argument('kak2pyb', type=str)
parser.add_argument('py2kaka', type=str)
parser.add_argument('py2kakb', type=str)
args = parser.parse_args()

kak2py = itertools.cycle([args.kak2pya, args.kak2pyb])
py2kak = itertools.cycle([args.py2kaka, args.py2kakb])


def reply(response):
    with open(next(py2kak), 'w') as f:
        f.write(response)


while True:
    with open(next(kak2py), 'r') as f:
        request = textwrap.dedent(f.read())
    exec(request)
    reply('fail "end of request"')
