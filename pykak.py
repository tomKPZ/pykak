#! /usr/bin/env python3

import argparse
import itertools
import textwrap


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('kak2pya', type=str)
_parser.add_argument('kak2pyb', type=str)
_parser.add_argument('py2kaka', type=str)
_parser.add_argument('py2kakb', type=str)
_args = _parser.parse_args()

_kak2py = itertools.cycle([_args.kak2pya, _args.kak2pyb])
_py2kak = itertools.cycle([_args.py2kaka, _args.py2kakb])


def _write(response):
    with open(next(_py2kak), 'w') as f:
        f.write(response)


def _read():
    with open(next(_kak2py), 'r') as f:
        return f.read()


def val(name):
    _write('pk_write "%%val{%s}"' % name)
    return _read()


while True:
    exec(textwrap.dedent(_read()))
    _write('fail "no failure, just end of request"')
