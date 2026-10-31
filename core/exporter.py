"""
Export utilities for Spotify tracks to CSV and TXT formats.
"""

import csv
import logging
from typing import List, Dict

logger = logging.getLogger(__name__)


def export_to_csv(filepath: str, tracks: List[Dict[str, str]]) -> int:
    """
    Exports tracks list to CSV file with utf-8-sig encoding and semicolon delimiter.
    Guarantees seamless opening in Russian Microsoft Excel.
    
    Returns:
        Number of exported tracks.
    """
    with open(filepath, mode="w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        # Header row
        writer.writerow(["№", "Исполнитель", "Название", "Ссылка", "Spotify ID"])

        for idx, track in enumerate(tracks, start=1):
            artist = track.get("artist", "").strip()
            title = track.get("title", "").strip()
            url = track.get("url", f"https://open.spotify.com/track/{track.get('id', '')}")
            track_id = track.get("id", "")

            writer.writerow([idx, artist, title, url, track_id])

    return len(tracks)


def export_to_txt(filepath: str, tracks: List[Dict[str, str]], include_numbering: bool = True) -> int:
    """
    Exports tracks list to plain TXT file with utf-8 encoding.
    Format: "1. Artist - Title" or "Artist - Title"
    
    Returns:
        Number of exported tracks.
    """
    with open(filepath, mode="w", encoding="utf-8") as f:
        for idx, track in enumerate(tracks, start=1):
            artist = track.get("artist", "").strip()
            title = track.get("title", "").strip()
            if include_numbering:
                line = f"{idx}. {artist} - {title}\n"
            else:
                line = f"{artist} - {title}\n"
            f.write(line)

    return len(tracks)


def format_tracks_as_text(tracks: List[Dict[str, str]], include_numbering: bool = False) -> str:
    """
    Formats track list into a multiline string for clipboard copying.
    """
    lines = []
    for idx, track in enumerate(tracks, start=1):
        artist = track.get("artist", "").strip()
        title = track.get("title", "").strip()
        if include_numbering:
            lines.append(f"{idx}. {artist} - {title}")
        else:
            lines.append(f"{artist} - {title}")
    return "\n".join(lines)
