"""Regression tests for bounded native CI execution (no simulator required)."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from run_ios_check import run_check, run_logged


class IOSCheckTests(unittest.TestCase):
    def test_records_output_and_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'test.log'
            status = run_logged([sys.executable, '-c',
                                 "print('diagnostic'); raise SystemExit(3)"], log, 10)
            self.assertEqual(status, 3)
            self.assertIn('diagnostic', log.read_text())

    def test_stalled_process_is_terminated(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'test.log'
            self.assertIsNone(run_logged(
                [sys.executable, '-c', 'import time; time.sleep(60)'], log, .1))

    @patch('run_ios_check.run_logged', return_value=1)
    def test_assertion_failure_does_not_retry(self, run):
        self.assertEqual(run_check('device', Path('.'), Path('logs')), 1)
        self.assertEqual(run.call_count, 1)

    @patch('run_ios_check.run_logged', side_effect=[None, 0, 0, 0, 0])
    def test_timeout_restarts_same_device_then_retries(self, run):
        self.assertEqual(run_check('device', Path('.'), Path('logs')), 0)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[1:4], [
            ['xcrun', 'simctl', 'shutdown', 'device'],
            ['xcrun', 'simctl', 'boot', 'device'],
            ['xcrun', 'simctl', 'bootstatus', 'device', '-b']])
        self.assertEqual(commands[0], commands[4])

    @patch('run_ios_check.run_logged', side_effect=[None, 0, 0, 0, None])
    def test_second_timeout_fails(self, run):
        self.assertEqual(run_check('device', Path('.'), Path('logs')), 124)
        self.assertEqual(run.call_count, 5)

    @patch('run_ios_check.run_logged', side_effect=[None, 1])
    def test_recovery_failure_stops(self, run):
        self.assertEqual(run_check('device', Path('.'), Path('logs')), 1)
        self.assertEqual(run.call_count, 2)


if __name__ == '__main__':
    unittest.main()
