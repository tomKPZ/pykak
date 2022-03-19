#! /usr/bin/env python3

import argparse
import itertools
import os
import textwrap
import traceback

# TODO:
# * reentrancy
#   - properly drain _replies
# * tests
# * figure out quoting (add helpers for quoting/unquoting?)
# * figure out how commands (exec/eval/etc) should be replicated
# * arguments to avoid arg(n)?


class KakException(Exception):
    pass


def _raw_write(response):
    with open(_py2kak, 'w') as f:
        f.write(response)


def _write(response):
    _raw_write(response)
    while True:
        dtype, data = _read()
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


def _read():
    with open(next(_kak2py), 'r') as f:
        dtype = f.read(1)
        data = f.read()
    return (dtype, data)


def _getter(prefix):
    def getter_impl(name):
        _write('pk_write "d%%%s{%s}"' % (prefix, name))
        return _replies.pop()
    return getter_impl


def execk(keys):
    evalc('exec ' + keys)


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('pk_dir', type=str)
_args = _parser.parse_args()

_kak2py_a = os.path.join(_args.pk_dir, 'kak2py_a.fifo')
_kak2py_b = os.path.join(_args.pk_dir, 'kak2py_b.fifo')
_kak2py = itertools.cycle((_kak2py_a, _kak2py_b))
_py2kak = os.path.join(_args.pk_dir, 'py2kak.fifo')

_replies = []

arg = _getter('arg')
opt = _getter('opt')
reg = _getter('reg')
val = _getter('val')
evalc = _write


while True:
    try:
        _replies.clear()
        dtype, data = _read()
        if dtype == 'r':
            exec(textwrap.dedent(data))
        else:
            raise Exception('not a request')
    except:
        exc = traceback.format_exc()
        # TODO: is this quoting sufficient?
        # TODO: coalesce commands.
        exc = exc.replace('"', '""').replace('%', '%%')
        _write('echo -markup "{Error}{\\}pykak error: '
               'see *debug* buffer"')
        _write('echo -debug "pykak error: %s"' % exc)
    _raw_write('alias global pk_done nop')
