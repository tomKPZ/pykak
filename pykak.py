#! /usr/bin/env python3

import argparse
import itertools
import os
import textwrap
import traceback


class KakException(Exception):
    pass


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('pk_dir', type=str)
_args = _parser.parse_args()

_kak2py_a = os.path.join(_args.pk_dir, 'kak2py_a.fifo')
_kak2py_b = os.path.join(_args.pk_dir, 'kak2py_b.fifo')
_kak2py = itertools.cycle((_kak2py_a, _kak2py_b))
_py2kak = os.path.join(_args.pk_dir, 'py2kak.fifo')

_replies = []


def _write(response):
    with open(_py2kak, 'w') as f:
        f.write(response)
    while True:
        dtype, data = _raw_read()
        if dtype == 'a':
            return
        elif dtype == 'd':
            _replies.append(data)
        elif dtype == 'r':
            raise Exception('reentrancy not supported yet')
        elif dtype == 'e':
            raise KakException(data)
        else:
            raise Exception('invalid reply type')


def _raw_read():
    with open(next(_kak2py), 'r') as f:
        dtype = f.read(1)
        data = f.read()
    return (dtype, data)


def _read():
    return _replies.pop()


def _getter(prefix):
    def getter_impl(name):
        _write('pk_write "d%%%s{%s}"' % (prefix, name))
        return _read()
    return getter_impl


arg = _getter('arg')
opt = _getter('opt')
reg = _getter('reg')
val = _getter('val')


while True:
    try:
        _replies.clear()
        dtype, data = _raw_read()
        if dtype == 'r':
            exec(textwrap.dedent(data))
        else:
            raise Exception('not a request')
    except:
        exc = traceback.format_exc().replace('"', '""')
        _write('echo -markup "{Error}{\\}pykak error: '
               'see *debug* buffer"')
        _write('echo -debug "pykak error: %s"' % exc)
    _write('alias global pk_done nop')
