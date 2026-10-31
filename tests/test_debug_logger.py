# -*- coding: utf-8 -*-
"""
Unit tests for core.debug_logger module.
"""

import unittest
from core.debug_logger import SessionDebugLogger


class TestSessionDebugLogger(unittest.TestCase):
    def setUp(self):
        self.logger = SessionDebugLogger.get_instance()
        self.logger.clear()

    def tearDown(self):
        self.logger.clear()

    def test_singleton_instance(self):
        l1 = SessionDebugLogger.get_instance()
        l2 = SessionDebugLogger.get_instance()
        self.assertIs(l1, l2)

    def test_log_error_and_count(self):
        self.assertEqual(self.logger.error_count(), 0)
        self.logger.log_error(
            track_number=7,
            artist="Radiohead",
            title="Nude",
            queries_tried=["ytsearch1:Radiohead - Nude official audio"],
            error_message="Age/censorship restriction",
            details="HTTP 403 Forbidden"
        )
        self.assertEqual(self.logger.error_count(), 1)

        errors = self.logger.get_errors()
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0]["artist"], "Radiohead")
        self.assertEqual(errors[0]["title"], "Nude")
        self.assertEqual(errors[0]["track_number"], 7)

    def test_export_text(self):
        self.logger.log_error(
            track_number=22,
            artist="Pixies",
            title="Hey",
            queries_tried=["ytsearch1:Pixies - Hey official audio"],
            error_message="Stub file rejected",
            details="Only 108 KB received"
        )
        report = self.logger.export_text()
        self.assertIn("Pixies", report)
        self.assertIn("Hey", report)
        self.assertIn("Stub file rejected", report)
        self.assertIn("SPOTIPARS", report)

    def test_clear(self):
        self.logger.log_error(1, "A", "T", ["q"], "err")
        self.assertEqual(self.logger.error_count(), 1)
        self.logger.clear()
        self.assertEqual(self.logger.error_count(), 0)


if __name__ == "__main__":
    unittest.main()
