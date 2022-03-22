#!/usr/bin/env python3
"""
This module defines a KakSender class to communicate with Kakoune sessions
over Unix sockets. It implements smooth scrolling when executed as a script.
"""

import sys
import os
import time
import socket

SEND_INTERVAL = 2e-3  # min time interval (in s) between two sent scroll events


class KakSender:
    """Helper to communicate with Kakoune's remote API using Unix sockets."""

    def __init__(self) -> None:
        self.session = os.environ['kak_session']
        self.client = os.environ['kak_client']
        self.socket_path = self._get_socket_path(self.session)

    def send_cmd(self, cmd: str, client: bool = False) -> bool:
        """
        Send a command string to the Kakoune session. Sent data is a
        concatenation of:
           - Header
             - Magic byte indicating type is "command" (\x02)
             - Length of whole message in uint32
           - Content
             - Length of command string in uint32
             - Command string
        Return whether the communication was successful.
        """
        if client:
            cmd = f"evaluate-commands -client {self.client} %😬{cmd}😬"
        b_cmd = cmd.encode('utf-8')
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(self.socket_path)
        b_content = self._encode_length(len(b_cmd)) + b_cmd
        b_header = b'\x02' + self._encode_length(len(b_content) + 5)
        b_message = b_header + b_content
        return sock.send(b_message) == len(b_message)

    def send_keys(self, keys: str) -> bool:
        """Send a sequence of keys to the client in the Kakoune session."""
        cmd = f"execute-keys -client {self.client} {keys}"
        return self.send_cmd(cmd)

    @staticmethod
    def _encode_length(str_length: int) -> bytes:
        return str_length.to_bytes(4, byteorder=sys.byteorder)

    @staticmethod
    def _get_socket_path(session: str) -> str:
        xdg_runtime_dir = os.environ.get('XDG_RUNTIME_DIR')
        if xdg_runtime_dir is None:
            tmpdir = os.environ.get('TMPDIR', '/tmp')
            session_path = os.path.join(
                tmpdir, f"kakoune-{os.environ['USER']}", session
            )
            if not os.path.exists(session_path):  # pre-Kakoune db9ef82
                session_path = os.path.join(
                    tmpdir, 'kakoune', os.environ['USER'], session
                )
        else:
            session_path = os.path.join(xdg_runtime_dir, 'kakoune', session)
        return session_path


class Scroller:
    """Class to send smooth scrolling events to Kakoune."""

    def __init__(self, interval: float, speed: int, max_duration: float) -> None:
        """
        Save scrolling parameters and initialize sender object. `interval`
        is the average step duration, `speed` is the size of each scroll step
        (0 implies inertial scrolling) and `max_duration` limits the total
        scrolling duration.
        """
        self.sender = KakSender()
        self.interval = interval
        self.speed = speed
        self.max_duration = max_duration

    def scroll_once(self, step: int, interval: float) -> None:
        """
        Send a scroll event of `step` lines to Kakoune client and make sure it
        takes at least `interval` seconds.
        """
        t_start = time.time()
        speed = abs(step)
        keys = f"{speed}j{speed}vj" if step > 0 else f"{speed}k{speed}vk"
        self.sender.send_keys(keys)
        self.sender.send_cmd("trigger-user-hook ScrollStep", client=True)
        t_end = time.time()
        elapsed = t_end - t_start
        if elapsed < interval:
            time.sleep(interval - elapsed)

    def linear_scroll(self, target: int, duration: float) -> None:
        """
        Do scrolling with a fixed velocity, moving `target` lines in `duration`
        seconds.
        """
        n_lines, step = abs(target), self.speed if target > 0 else -self.speed
        times = n_lines // max(self.speed, 1)
        interval = duration / (times - 1)

        t_init = time.time()
        for i in range(times):
            if time.time() - t_init > duration:
                self.scroll_once(step * (times - i), 0)
                break
            self.scroll_once(step, interval * (i < times - 1))

    def inertial_scroll(self, target: int, duration: float) -> None:
        """
        Do scrolling with inertial movement, moving `target` lines in `duration`
        seconds. Velocity decreases linearly at each step towards zero.

        Compute initial velocity v_1 such that the total duration (omitting the
        final step) matches given `duration`. For S = abs(target) this is
        obtained by solving the formula

            duration = sum_{i=1}^{S-1} 1/v_i

        where v_i = v_1*(S-i+1)/S. Assumes `duration` > 0.
        """
        n_lines, step = abs(target), 1 if target > 0 else -1
        velocity = n_lines * sum(1.0 / x for x in range(2, n_lines + 1)) / duration  # type: ignore
        d_velocity = velocity / n_lines

        # keep track of total steps and interval for potential batching
        # before sending a scroll event
        q_step, q_duration = 0, 0.0

        t_init = time.time()
        for i in range(n_lines):
            # shortcut to the end if we are past total duration
            if time.time() - t_init > duration:
                self.scroll_once(step * (n_lines - i), 0)
                break

            # compute sleep interval and update velocity
            interval = 1 / velocity * (i < n_lines - 1)
            velocity -= d_velocity

            # update queue then check if we are past the event send interval
            q_duration += interval
            q_step += step
            if i == n_lines - 1 or q_duration >= SEND_INTERVAL:
                self.scroll_once(q_step, q_duration)
                q_step, q_duration = 0, 0.0

    def scroll(self, amount: int) -> None:
        """
        Do smooth scrolling using KakSender methods. `amount` is the total
        number of lines to scroll; positive for down, negative for up.
        Assumes abs(amount) > 1.
        """
        duration = min((abs(amount) - 1) * self.interval, self.max_duration)

        # smoothly scroll to target
        if self.speed > 0:  # fixed speed scroll
            self.linear_scroll(amount, duration)
        else:  # inertial scroll
            self.inertial_scroll(amount, duration)

        # report we are done
        self.sender.send_cmd('set-option window scroll_running ""', client=True)


def parse_options(option_name: str) -> dict:
    """Parse a Kakoune map option and return a str-to-str dict."""
    items = [
        elt.split('=', maxsplit=1)
        for elt in os.environ[f"kak_opt_{option_name}"].split()
    ]
    return {v[0]: v[1] for v in items}


def main() -> None:
    """Parse options from environment variable and call scroller."""
    amount = int(sys.argv[1])

    options = parse_options("scroll_options")

    # interval between ticks, convert ms to s
    interval = float(options.get("interval", 10)) / 1000

    # number of lines per tick
    speed = int(options.get("speed", 0))

    # max amount of time to scroll, convert ms to s
    max_duration = int(options.get("max_duration", 1000)) / 1000

    scroller = Scroller(interval, speed, max_duration)
    scroller.scroll(amount)


if __name__ == '__main__':
    main()
