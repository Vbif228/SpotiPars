"""
Unit tests for core.downloader module.
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from core.downloader import (
    sanitize_filename,
    build_filename,
    tag_audio_file,
)
from mutagen.mp3 import MP3
from mutagen.id3 import ID3


class TestDownloaderUtils(unittest.TestCase):
    def test_sanitize_filename(self):
        # Forbidden Windows chars: \ / : * ? " < > |
        dirty = 'AC/DC: Back in Black *Remastered?* <Special> "Edition" | Track. '
        cleaned = sanitize_filename(dirty)
        self.assertNotIn("/", cleaned)
        self.assertNotIn("\\", cleaned)
        self.assertNotIn(":", cleaned)
        self.assertNotIn("*", cleaned)
        self.assertNotIn("?", cleaned)
        self.assertNotIn('"', cleaned)
        self.assertNotIn("<", cleaned)
        self.assertNotIn(">", cleaned)
        self.assertNotIn("|", cleaned)
        self.assertFalse(cleaned.endswith("."))
        self.assertFalse(cleaned.endswith(" "))
        self.assertEqual(cleaned, "ACDC Back in Black Remastered Special Edition  Track")

    def test_build_filename_with_number(self):
        fn = build_filename(1, "Rick Astley", "Never Gonna Give You Up", "mp3", include_number=True)
        self.assertEqual(fn, "001. Rick Astley - Never Gonna Give You Up.mp3")

        fn2 = build_filename(42, "The Weeknd", "Blinding Lights", "flac", include_number=True)
        self.assertEqual(fn2, "042. The Weeknd - Blinding Lights.flac")

    def test_build_filename_dynamic_padding(self):
        # Playlist with <= 999 tracks -> 3 digits (001.)
        fn_small = build_filename(5, "Artist", "Title", "mp3", total_tracks=200)
        self.assertEqual(fn_small, "005. Artist - Title.mp3")

        # Playlist with 1,500 tracks -> 4 digits (0005., 1499.)
        fn_large = build_filename(5, "Artist", "Title", "mp3", total_tracks=1500)
        self.assertEqual(fn_large, "0005. Artist - Title.mp3")

        fn_large_last = build_filename(1499, "Artist", "Title", "flac", total_tracks=1500)
        self.assertEqual(fn_large_last, "1499. Artist - Title.flac")

        # Playlist with 12,000 tracks -> 5 digits (00042.)
        fn_huge = build_filename(42, "Artist", "Title", "mp3", total_tracks=12000)
        self.assertEqual(fn_huge, "00042. Artist - Title.mp3")

    def test_build_filename_without_number(self):
        fn = build_filename(1, "Rick Astley", "Never Gonna Give You Up", "mp3", include_number=False)
        self.assertEqual(fn, "Rick Astley - Never Gonna Give You Up.mp3")

    def test_build_filename_templates(self):
        fn_default = build_filename(7, "Radiohead", "Nude", "mp3", template="Исполнитель - Название")
        self.assertEqual(fn_default, "Radiohead - Nude.mp3")

        fn_dot = build_filename(7, "Radiohead", "Nude", "flac", template="001. Исполнитель - Название")
        self.assertEqual(fn_dot, "007. Radiohead - Nude.flac")

        fn_dash = build_filename(7, "Radiohead", "Nude", "mp3", template="001 - Исполнитель - Название")
        self.assertEqual(fn_dash, "007 - Radiohead - Nude.mp3")


class TestMetadataTagging(unittest.TestCase):
    def test_mp3_tagging(self):
        # Create a minimal mock MP3 file with MPEG sync header
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp_path = tmp.name
            # Write minimal valid MP3 frame
            tmp.write(b"\xff\xfb\x90\x44" + b"\x00" * 1024)

        try:
            sample_cover = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 100 # Mock JPEG
            tag_audio_file(
                tmp_path,
                artist="Test Artist",
                title="Test Title",
                album="Test Album",
                track_number=7,
                cover_bytes=sample_cover
            )

            # Read back tags using ID3
            tags = ID3(tmp_path)
            self.assertEqual(str(tags.get("TIT2")), "Test Title")
            self.assertEqual(str(tags.get("TPE1")), "Test Artist")
            self.assertEqual(str(tags.get("TALB")), "Test Album")
            self.assertEqual(str(tags.get("TRCK")), "7")
            apic = tags.get("APIC:Cover")
            self.assertIsNotNone(apic)
            self.assertEqual(apic.mime, "image/jpeg")
            self.assertEqual(apic.type, 3)
            self.assertEqual(apic.data, sample_cover)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


class TestSmartDeduplication(unittest.TestCase):
    def test_smart_deduplication_different_number(self):
        from core.downloader import AudioDownloader
        with tempfile.TemporaryDirectory() as tmpdir:
            # Suppose track 20 was previously downloaded
            old_file = os.path.join(tmpdir, "020. Pixies - Hey.mp3")
            with open(old_file, "wb") as f:
                f.write(b"MOCK_AUDIO_DATA" * 1000) # > 10 KB

            downloader = AudioDownloader(max_workers=1)
            # Now user downloads a new playlist where Hey is track #5
            res = downloader.download_single_track(
                track_info={"artist": "Pixies", "title": "Hey"},
                track_number=5,
                output_dir=tmpdir,
                audio_format="mp3",
                include_number=True
            )
            # Should detect existing file and skip without network
            self.assertEqual(res["status"], "SKIPPED")
            self.assertIn("Pixies - Hey.mp3", res["filename"])


if __name__ == "__main__":
    unittest.main()
