#! /usr/bin/env python3

import argparse
import itertools
import textwrap
import traceback


class KakException(Exception):
    pass


_ERROR_UUID = 'f74c66de-3e90-4ee5-ae33-bf7e8e358cb0'

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
        data = f.read()
    if data.startswith(_ERROR_UUID):
        raise KakException(data.removeprefix(_ERROR_UUID))
    return data


def _getter(prefix):
    def getter_impl(name):
        _write('pk_write "%%%s{%s}"' % (prefix, str(name)))
        return _read()
    return getter_impl


arg = _getter('arg')
opt = _getter('opt')
reg = _getter('reg')
val = _getter('val')


while True:
    try:
        exec(textwrap.dedent(_read()))
    except:
        exc = traceback.format_exc().replace('"', '""')
        _write('echo "pykak error: see *debug* buffer"')
        _write('echo -debug "pykak error: %s"' % exc)
    _write('alias global pk_done nop')
