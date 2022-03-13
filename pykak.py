#! /usr/bin/env python3

import argparse
import textwrap
import sys


def main():
    parser = argparse.ArgumentParser('pykak server')
    parser.add_argument('kak2py', type=str)
    parser.add_argument('py2kak', type=str)
    args = parser.parse_args()

    def reply(response):
        open(args.py2kak, 'w').write(response)
    while True:
        request = textwrap.dedent(open(args.kak2py).read())
        exec(request)
    return 0


if __name__ == '__main__':
    sys.exit(main())
