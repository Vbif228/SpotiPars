"""
GUI automated verification test.
Instantiates SpotiParsApp, tests widget hierarchy, simulates processing tracks,
and validates treeview updates.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from ui.app import SpotiParsApp


class TestGUI(unittest.TestCase):
    def test_gui_initialization_and_mock_data(self):
        app = SpotiParsApp()
        app.update_idletasks()

        # Check core widgets exist
        self.assertIsNotNone(app.btn_paste)
        self.assertIsNotNone(app.btn_manual)
        self.assertIsNotNone(app.btn_clear)
        self.assertIsNotNone(app.format_selector)
        self.assertIsNotNone(app.opt_naming)
        self.assertIsNotNone(app.chk_subfolder)
        self.assertIsNotNone(app.btn_download)
        self.assertIsNotNone(app.btn_stop_download)
        self.assertIsNotNone(app.tree)
        self.assertIsNotNone(app.progress_bar)

        # Mock tracks
        mock_tracks = [
            {
                "id": "4cOdK2wGLETKBW3PvgPWqT",
                "artist": "Rick Astley",
                "title": "Never Gonna Give You Up",
                "url": "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT",
                "status": "OK"
            },
            {
                "id": "2sFepQNyl1WjpROruP8bJ0",
                "artist": "Tate McRae",
                "title": "Housewife",
                "url": "https://open.spotify.com/track/2sFepQNyl1WjpROruP8bJ0",
                "status": "OK"
            }
        ]

        app._on_fetching_complete(mock_tracks)
        app.update_idletasks()

        # Verify items in treeview
        children = app.tree.get_children()
        self.assertEqual(len(children), 2)

        row0 = app.tree.item(children[0])["values"]
        self.assertEqual(str(row0[0]), "1")
        self.assertEqual(row0[1], "Rick Astley")
        self.assertEqual(row0[2], "Never Gonna Give You Up")
        self.assertEqual(row0[3], "Готов")

        row1 = app.tree.item(children[1])["values"]
        self.assertEqual(str(row1[0]), "2")
        self.assertEqual(row1[1], "Tate McRae")
        self.assertEqual(row1[2], "Housewife")

        # Test clear
        app._on_clear_clicked()
        app.update_idletasks()
        self.assertEqual(len(app.tree.get_children()), 0)
        self.assertEqual(len(app.tracks), 0)

        app.destroy()


if __name__ == "__main__":
    unittest.main()
