#!/usr/bin/env python3
"""Run native iOS tests with bounded simulator recovery and retained logs."""
import argparse
import os
from pathlib import Path
import signal
import subprocess


def run_logged(command, log_path, timeout, cwd=None):
    """Return the process status, or None after terminating a timed-out group."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(f'Running {command[0]} (log: {log_path}, limit: {timeout}s)', flush=True)
    with log_path.open('w') as output:
        process = subprocess.Popen(command, cwd=cwd, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            print(f'Timed out: {log_path}', flush=True)
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
            # The leader may exit before its Xcode/Flutter descendants.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            return None


def run_check(device, fixture, logs, flutter='flutter', timeout=600):
    command = [flutter, 'test', '--no-pub', '--verbose',
               'integration_test/navigation_test.dart', '-d', device]
    for attempt in (1, 2):
        status = run_logged(command, logs / f'attempt-{attempt}.log', timeout, fixture)
        if status is not None:
            return status  # Never retry or conceal an assertion/build failure.
        if attempt == 1:
            # Restart only the selected simulator; never erase its data.
            status = run_logged(['xcrun', 'simctl', 'shutdown', device],
                                logs / 'shutdown.log', 60)
            if status != 0:
                return 1
            for operation in (['boot', device], ['bootstatus', device, '-b']):
                status = run_logged(['xcrun', 'simctl', *operation],
                                    logs / f'{operation[0]}.log', 180)
                if status != 0:
                    return 1
    return 124


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--fixture', type=Path, default=Path('build/native_fixture'))
    parser.add_argument('--logs', type=Path, default=Path('build/ios-check-logs'))
    parser.add_argument('--flutter', default='flutter')
    args = parser.parse_args()
    return run_check(args.device, args.fixture.resolve(), args.logs.resolve(), args.flutter)


if __name__ == '__main__':
    raise SystemExit(main())
