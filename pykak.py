#! /usr/bin/env python3

import argparse
import collections
import itertools
import textwrap
import traceback


class KakException(Exception):
    pass


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('kak2pya', type=str)
_parser.add_argument('kak2pyb', type=str)
_parser.add_argument('py2kak', type=str)
_args = _parser.parse_args()

_kak2py = itertools.cycle([_args.kak2pya, _args.kak2pyb])

_replies = collections.deque()


def _write(response):
    with open(_args.py2kak, 'w') as f:
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
