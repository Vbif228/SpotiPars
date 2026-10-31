"""
Core Spotify Scraping Engine.
Extracts track IDs from Spotify links and retrieves Artist & Title without Spotify API keys.
"""

import re
import json
import logging
from typing import List, Dict, Optional, Tuple, Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# Regex pattern matching Spotify track URLs and URIs
# Matches:
# - https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT
# - https://open.spotify.com/intl-ru/track/4cOdK2wGLETKBW3PvgPWqT?si=...
# - spotify:track:4cOdK2wGLETKBW3PvgPWqT
TRACK_REGEX = re.compile(
    r'(?:spotify:track:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?track/)([a-zA-Z0-9]{22})'
)

BROWSER_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

CRAWLER_UA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"


def extract_track_ids(text: str) -> List[str]:
    """
    Extracts all unique track IDs from text in the order they appear.
    Preserves exact order of appearance.
    """
    if not text:
        return []
    
    matches = TRACK_REGEX.findall(text)
    # Maintain order while allowing duplicates if user actually copied duplicate tracks,
    # or keep duplicates as in clipboard:
    return matches


class SpotifyScraper:
    """
    Scrapes track information using public embed pages, OpenGraph tags, and oEmbed.
    Thread-safe and supports multi-threaded batch fetching.
    """

    def __init__(self, timeout: int = 10, max_workers: int = 16):
        self.timeout = timeout
        self.max_workers = max_workers
        self._cache: Dict[str, Dict[str, str]] = {}
        self._session = requests.Session()

    def fetch_single_track(self, track_id: str) -> Dict[str, str]:
        """
        Fetches artist and title for a single track ID.
        Uses multi-tier fallback:
        1. Embed __NEXT_DATA__
        2. Crawler OpenGraph tags
        3. oEmbed API
        """
        if track_id in self._cache:
            return dict(self._cache[track_id])

        # --- Tier 1: Embed page with __NEXT_DATA__ ---
        try:
            embed_url = f"https://open.spotify.com/embed/track/{track_id}"
            headers = {"User-Agent": BROWSER_UA, "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7"}
            resp = self._session.get(embed_url, headers=headers, timeout=self.timeout)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                script = soup.find("script", id="__NEXT_DATA__")
                if script and script.string:
                    data = json.loads(script.string)
                    entity = (
                        data.get("props", {})
                        .get("pageProps", {})
                        .get("state", {})
                        .get("data", {})
                        .get("entity", {})
                    )
                    title = entity.get("name") or entity.get("title")
                    artists_list = entity.get("artists", [])
                    artists = ", ".join(
                        [a.get("name") for a in artists_list if a.get("name")]
                    )
                    album = entity.get("album", {}).get("name") or ""
                    images = entity.get("visualIdentity", {}).get("image", [])
                    cover_url = ""
                    if images:
                        cover_url = max(images, key=lambda x: x.get("maxWidth", 0)).get("url", "")

                    if title:
                        result = {
                            "id": track_id,
                            "artist": artists or "Неизвестный исполнитель",
                            "title": title.strip(),
                            "album": album.strip(),
                            "cover_url": cover_url,
                            "url": f"https://open.spotify.com/track/{track_id}",
                            "status": "OK",
                        }
                        self._cache[track_id] = result
                        return result
        except Exception as e:
            logger.debug(f"Tier 1 failed for {track_id}: {e}")

        # --- Tier 2: OpenGraph crawler fallback ---
        try:
            track_url = f"https://open.spotify.com/track/{track_id}"
            headers = {"User-Agent": CRAWLER_UA}
            resp = self._session.get(track_url, headers=headers, timeout=self.timeout)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, "html.parser")
                og_title = soup.find("meta", property="og:title") or soup.find(
                    "meta", attrs={"name": "og:title"}
                )
                og_desc = soup.find("meta", property="og:description") or soup.find(
                    "meta", attrs={"name": "og:description"}
                )
                og_image = soup.find("meta", property="og:image") or soup.find(
                    "meta", attrs={"name": "og:image"}
                )

                title = og_title["content"].strip() if og_title and og_title.get("content") else ""
                desc = og_desc["content"].strip() if og_desc and og_desc.get("content") else ""
                cover_url = og_image["content"].strip() if og_image and og_image.get("content") else ""

                artist = ""
                album = ""
                if desc:
                    parts = desc.split(" · ") if " · " in desc else desc.split(" - ")
                    if len(parts) >= 1:
                        artist = parts[0].strip()
                    if len(parts) >= 2:
                        album = parts[1].strip()

                if title:
                    result = {
                        "id": track_id,
                        "artist": artist or "Неизвестный исполнитель",
                        "title": title,
                        "album": album,
                        "cover_url": cover_url,
                        "url": track_url,
                        "status": "OK",
                    }
                    self._cache[track_id] = result
                    return result
        except Exception as e:
            logger.debug(f"Tier 2 failed for {track_id}: {e}")

        # --- Tier 3: oEmbed API fallback ---
        try:
            oe_url = f"https://open.spotify.com/oembed?url=https://open.spotify.com/track/{track_id}"
            resp = self._session.get(oe_url, timeout=self.timeout)
            if resp.status_code == 200:
                oe_json = resp.json()
                raw_title = oe_json.get("title", "").strip()
                cover_url = oe_json.get("thumbnail_url", "")
                if raw_title:
                    artist = "Spotify Track"
                    title = raw_title
                    if " - " in raw_title:
                        parts = raw_title.split(" - ", 1)
                        artist = parts[0].strip()
                        title = parts[1].strip()
                    result = {
                        "id": track_id,
                        "artist": artist,
                        "title": title,
                        "album": "",
                        "cover_url": cover_url,
                        "url": f"https://open.spotify.com/track/{track_id}",
                        "status": "OK",
                    }
                    self._cache[track_id] = result
                    return result
        except Exception as e:
            logger.debug(f"Tier 3 failed for {track_id}: {e}")

        # Fallback if all failed
        failed_res = {
            "id": track_id,
            "artist": "Не удалось загрузить",
            "title": f"Трек {track_id}",
            "album": "",
            "cover_url": "",
            "url": f"https://open.spotify.com/track/{track_id}",
            "status": "ERROR",
        }
        return failed_res

    def fetch_tracks_batch(
        self,
        track_ids: List[str],
        progress_callback: Optional[Callable[[int, int, Dict[str, str]], None]] = None,
        is_cancelled: Optional[Callable[[], bool]] = None,
    ) -> List[Dict[str, str]]:
        """
        Fetches information for a list of track IDs concurrently.
        GUARANTEES: Result order strictly matches input track_ids order.
        
        Args:
            track_ids: List of Spotify track IDs.
            progress_callback: Optional callback fn(completed_count, total_count, item_data)
            is_cancelled: Optional callback returning True if process should abort.
        """
        total = len(track_ids)
        if total == 0:
            return []

        results = [None] * total
        completed_count = 0

        indexed_tasks = list(enumerate(track_ids))

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit worker wrapper returning (index, result)
            future_to_idx = {
                executor.submit(self.fetch_single_track, tid): idx
                for idx, tid in indexed_tasks
            }

            for future in as_completed(future_to_idx):
                if is_cancelled and is_cancelled():
                    break

                idx = future_to_idx[future]
                try:
                    res = future.result()
                except Exception as e:
                    tid = track_ids[idx]
                    res = {
                        "id": tid,
                        "artist": "Ошибка запроса",
                        "title": str(e),
                        "album": "",
                        "cover_url": "",
                        "url": f"https://open.spotify.com/track/{tid}",
                        "status": "ERROR",
                    }

                results[idx] = res
                completed_count += 1

                if progress_callback:
                    progress_callback(completed_count, total, res)

        # Fill any uncompleted items in case of cancellation
        for idx, item in enumerate(results):
            if item is None:
                tid = track_ids[idx]
                results[idx] = {
                    "id": tid,
                    "artist": "Отменено",
                    "title": "Отменено пользователем",
                    "album": "",
                    "cover_url": "",
                    "url": f"https://open.spotify.com/track/{tid}",
                    "status": "CANCELLED",
                }

        return results
