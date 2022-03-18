#! /usr/bin/env python3

import argparse
import collections
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

_replies = collections.deque()


def _write(response):
    with open(_py2kak, 'w') as f:
        f.write(response)
    while True:
        data = _raw_read()
        # TODO: fix this
        if not data:
            return
        _replies.append(data)


def _raw_read():
    with open(next(_kak2py), 'r') as f:
        dtype = f.read(1)
        data = f.read()
    if dtype == 'e':
        raise KakException(data)
    return data


def _read():
    return _replies.popleft()


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
        exec(textwrap.dedent(_raw_read()))
    except:
        exc = traceback.format_exc().replace('"', '""')
        _write('echo -markup "{Error}{\\}pykak error: '
               'see *debug* buffer"')
        _write('echo -debug "pykak error: %s"' % exc)
    _write('alias global pk_done nop')
