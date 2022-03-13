#! /usr/bin/env python3

import argparse
import sys


def main():
    parser = argparse.ArgumentParser('pykak server')
    parser.add_argument('kak2py', type=str)
    parser.add_argument('py2kak', type=str)
    args = parser.parse_args()
    while True:
        request = open(args.kak2py).read()
        response = 'echo "pykak response"'
        open(args.py2kak, 'w').write(response)
    return 0


if __name__ == '__main__':
    sys.exit(main())
