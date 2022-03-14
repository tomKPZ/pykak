#! /usr/bin/env python3

import argparse
import itertools
import textwrap


parser = argparse.ArgumentParser('pykak server')
parser.add_argument('kak2pya', type=str)
parser.add_argument('kak2pyb', type=str)
parser.add_argument('py2kaka', type=str)
parser.add_argument('py2kakb', type=str)
args = parser.parse_args()

kak2py = itertools.cycle([args.kak2pya, args.kak2pyb])
py2kak = itertools.cycle([args.py2kaka, args.py2kakb])


def put(response):
    with open(next(py2kak), 'w') as f:
        f.write(response)


def get():
    with open(next(kak2py), 'r') as f:
        return f.read()


def val(name):
    put('pykak-request "%%val{%s}"' % name)
    return get()


while True:
    exec(textwrap.dedent(get()))
    put('fail "no failure, just end of request"')
