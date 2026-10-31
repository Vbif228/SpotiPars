"""
Unit and integration tests for SpotiPars core modules.
"""

import os
import sys
import tempfile
import unittest

# Add project root to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from core.scraper import extract_track_ids, SpotifyScraper
from core.exporter import export_to_csv, export_to_txt, format_tracks_as_text


class TestScraper(unittest.TestCase):
    def test_extract_track_ids(self):
        text = """
        Here are some tracks:
        https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT
        Another one with params:
        https://open.spotify.com/track/2sFepQNyl1WjpROruP8bJ0?si=1234567890abcdef
        URI format:
        spotify:track:7bxaFZ1O3cHkgLKMsdC3xR
        Intl localized URL:
        https://open.spotify.com/intl-ru/track/3h5T5JypYU7huFiVYhv1dr
        Duplicate of first:
        https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT
        """
        extracted = extract_track_ids(text)
        expected = [
            "4cOdK2wGLETKBW3PvgPWqT",
            "2sFepQNyl1WjpROruP8bJ0",
            "7bxaFZ1O3cHkgLKMsdC3xR",
            "3h5T5JypYU7huFiVYhv1dr",
            "4cOdK2wGLETKBW3PvgPWqT",
        ]
        self.assertEqual(extracted, expected, "Extracted track IDs must match in order")

    def test_single_track_fetch(self):
        scraper = SpotifyScraper(timeout=10)
        # Rick Astley - Never Gonna Give You Up
        res = scraper.fetch_single_track("4cOdK2wGLETKBW3PvgPWqT")
        self.assertEqual(res["status"], "OK")
        self.assertIn("Astley", res["artist"])
        self.assertEqual(res["title"], "Never Gonna Give You Up")

    def test_batch_fetch_order_preservation(self):
        scraper = SpotifyScraper(timeout=10, max_workers=8)
        test_ids = [
            "4cOdK2wGLETKBW3PvgPWqT",
            "2sFepQNyl1WjpROruP8bJ0",
            "7bxaFZ1O3cHkgLKMsdC3xR",
        ]
        results = scraper.fetch_tracks_batch(test_ids)
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0]["id"], test_ids[0])
        self.assertEqual(results[1]["id"], test_ids[1])
        self.assertEqual(results[2]["id"], test_ids[2])


class TestExporter(unittest.TestCase):
    def setUp(self):
        self.sample_tracks = [
            {
                "id": "4cOdK2wGLETKBW3PvgPWqT",
                "artist": "Rick Astley",
                "title": "Never Gonna Give You Up",
                "url": "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT",
            },
            {
                "id": "test_cyrillic_id",
                "artist": "Кино",
                "title": "Группа крови",
                "url": "https://open.spotify.com/track/test_cyrillic_id",
            },
        ]

    def test_csv_export(self):
        with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            count = export_to_csv(tmp_path, self.sample_tracks)
            self.assertEqual(count, 2)

            with open(tmp_path, "rb") as f:
                content_bytes = f.read()

            # Check UTF-8 BOM: 0xEF, 0xBB, 0xBF
            self.assertTrue(
                content_bytes.startswith(b"\xef\xbb\xbf"),
                "CSV must start with UTF-8 BOM for Excel compatibility",
            )

            # Check text and delimiter
            text = content_bytes.decode("utf-8-sig")
            lines = text.strip().split("\r\n")
            if len(lines) == 1:
                lines = text.strip().split("\n")
            self.assertEqual(lines[0], "№;Исполнитель;Название;Ссылка;Spotify ID")
            self.assertIn("1;Rick Astley;Never Gonna Give You Up;", lines[1])
            self.assertIn("2;Кино;Группа крови;", lines[2])
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_txt_export(self):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            count = export_to_txt(tmp_path, self.sample_tracks, include_numbering=True)
            self.assertEqual(count, 2)

            with open(tmp_path, "r", encoding="utf-8") as f:
                content = f.read()

            self.assertIn("1. Rick Astley - Never Gonna Give You Up\n", content)
            self.assertIn("2. Кино - Группа крови\n", content)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_format_tracks_as_text(self):
        text = format_tracks_as_text(self.sample_tracks, include_numbering=False)
        self.assertEqual(text, "Rick Astley - Never Gonna Give You Up\nКино - Группа крови")


if __name__ == "__main__":
    unittest.main()
