"""
Audio Downloader and Metadata Tagger Module.
Downloads audio using yt-dlp, converts via FFmpeg to MP3 (320 kbps) or FLAC,
and injects ID3/FLAC metadata with cover art using mutagen.
"""

import os
import re
import sys
import time
import logging
from typing import List, Dict, Optional, Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

import yt_dlp
import mutagen
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB, TRCK, APIC, ID3NoHeaderError
from mutagen.flac import FLAC, Picture

from core.ffmpeg_setup import ensure_ffmpeg_in_path
from core.debug_logger import SessionDebugLogger

logger = logging.getLogger(__name__)

# Invalid filename characters on Windows: \ / : * ? " < > |
WINDOWS_INVALID_CHARS = re.compile(r'[\\/*?:"<>|]')


def sanitize_filename(name: str, max_length: int = 120) -> str:
    """
    Sanitizes string for use as a Windows filename.
    Removes invalid characters, strips leading/trailing spaces and dots,
    and caps length.
    """
    if not name:
        return "Unknown"

    # Replace invalid chars with an empty string or hyphen
    clean = WINDOWS_INVALID_CHARS.sub("", name)
    # Remove control characters
    clean = "".join(ch for ch in clean if ord(ch) >= 32)
    # Strip leading/trailing dots and whitespace (forbidden in Windows filenames)
    clean = clean.strip(". ")

    if not clean:
        clean = "Track"

    return clean[:max_length]


def clean_track_title(title: str) -> str:
    """
    Cleans remastered tags, deluxe editions, and punctuation that confuse YouTube/SoundCloud search.
    E.g. 'Bone Machine - 2007 Remaster' -> 'Bone Machine'
         'Why Won't They Talk To Me?' -> 'Why Won't They Talk To Me'
    """
    if not title:
        return ""
    cleaned = re.sub(r"\s*[-–—]\s*(?:\d{4}\s*)?Remaster(?:ed)?.*", "", title, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*\(.*Remaster(?:ed)?.*\)", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*\(.*Deluxe.*\)", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*[-–—]\s*Single\s*Version.*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"[?!]", "", cleaned)
    cleaned = cleaned.strip()
    return cleaned if cleaned else title


def build_filename(
    track_number: int,
    artist: str,
    title: str,
    ext: str,
    include_number: bool = True,
    total_tracks: int = 0,
    template: str = ""
) -> str:
    """
    Constructs clean, safe filename with template and dynamic zero-padding.
    Supports templates:
      - "Исполнитель - Название" -> "Artist - Title.ext"
      - "001. Исполнитель - Название" -> "001. Artist - Title.ext"
      - "001 - Исполнитель - Название" -> "001 - Artist - Title.ext"
      - "001. Название" -> "001. Title.ext"
    """
    safe_artist = sanitize_filename(artist, max_length=60)
    safe_title = sanitize_filename(title, max_length=90)
    safe_ext = ext.lstrip(".").lower()

    pad_width = max(3, len(str(total_tracks))) if total_tracks > 0 else 3
    num_str = f"{track_number:0{pad_width}d}"

    if template:
        if "001." in template:
            return f"{num_str}. {safe_artist} - {safe_title}.{safe_ext}"
        elif "001 -" in template:
            return f"{num_str} - {safe_artist} - {safe_title}.{safe_ext}"
        elif "001" in template:
            return f"{num_str}. {safe_artist} - {safe_title}.{safe_ext}"
        elif template == "Исполнитель - Название":
            return f"{safe_artist} - {safe_title}.{safe_ext}"

    if include_number:
        return f"{num_str}. {safe_artist} - {safe_title}.{safe_ext}"

    return f"{safe_artist} - {safe_title}.{safe_ext}"


def fetch_cover_bytes(cover_url: str, timeout: int = 8) -> Optional[bytes]:
    """Downloads cover art image as bytes."""
    if not cover_url:
        return None
    try:
        resp = requests.get(cover_url, timeout=timeout)
        if resp.status_code == 200 and resp.content:
            return resp.content
    except Exception as e:
        logger.debug(f"Failed to download cover art from {cover_url}: {e}")
    return None


def tag_audio_file(
    filepath: str,
    artist: str,
    title: str,
    album: str = "",
    track_number: int = 1,
    cover_bytes: Optional[bytes] = None
) -> None:
    """
    Injects metadata and album art into MP3 or FLAC file using mutagen.
    Uses ID3v2.3 for MP3 (maximum player / car audio compatibility).
    """
    ext = os.path.splitext(filepath)[1].lower()

    if ext == ".mp3":
        try:
            tags = ID3(filepath)
        except ID3NoHeaderError:
            tags = ID3()

        # Set ID3v2.3 tags
        tags.add(TIT2(encoding=3, text=title))
        tags.add(TPE1(encoding=3, text=artist))
        if album:
            tags.add(TALB(encoding=3, text=album))
        tags.add(TRCK(encoding=3, text=str(track_number)))

        if cover_bytes:
            tags.add(
                APIC(
                    encoding=3,
                    mime="image/jpeg",
                    type=3,  # Front cover
                    desc="Cover",
                    data=cover_bytes
                )
            )
        # v2_version=3 ensures ID3v2.3 for maximum compatibility
        tags.save(filepath, v2_version=3)

    elif ext == ".flac":
        audio = FLAC(filepath)
        audio["title"] = title
        audio["artist"] = artist
        if album:
            audio["album"] = album
        audio["tracknumber"] = str(track_number)

        if cover_bytes:
            pic = Picture()
            pic.type = 3  # Front cover
            pic.mime = "image/jpeg"
            pic.desc = "Cover"
            pic.data = cover_bytes
            audio.clear_pictures()
            audio.add_picture(pic)

        audio.save()


class AudioDownloader:
    """
    Downloads audio streams for tracks using yt-dlp and FFmpeg,
    tags files with mutagen, and coordinates multi-threaded batch operations.
    """

    def __init__(self, max_workers: int = 4):
        self.max_workers = max_workers
        ensure_ffmpeg_in_path()

    def download_single_track(
        self,
        track_info: Dict[str, str],
        track_number: int,
        output_dir: str,
        audio_format: str = "mp3",  # 'mp3' or 'flac'
        include_number: bool = False,
        total_tracks: int = 0,
        status_callback: Optional[Callable[[int, str], None]] = None,
        is_cancelled: Optional[Callable[[], bool]] = None,
        naming_template: str = ""
    ) -> Dict[str, str]:
        """
        Downloads and tags a single track.
        Returns dict with status, filepath, and error details if any.
        """
        if is_cancelled and is_cancelled():
            return {"status": "CANCELLED", "filepath": "", "error": "Cancelled"}

        artist = track_info.get("artist", "Unknown Artist").strip()
        title = track_info.get("title", "Unknown Title").strip()
        album = track_info.get("album", "").strip()
        cover_url = track_info.get("cover_url", "").strip()

        ext = audio_format.lower()
        target_filename = build_filename(
            track_number=track_number,
            artist=artist,
            title=title,
            ext=ext,
            include_number=include_number,
            total_tracks=total_tracks,
            template=naming_template
        )
        target_filepath = os.path.join(output_dir, target_filename)

        # 1. Skip if exact target file already exists and has non-zero size
        if os.path.exists(target_filepath) and os.path.getsize(target_filepath) > 10240:
            if status_callback:
                status_callback(track_number, "Пропущен (уже скачан)")
            return {
                "status": "SKIPPED",
                "filepath": target_filepath,
                "filename": target_filename
            }

        # 1b. Smart Deduplication: check if track already exists in folder with different numbering or without numbers
        safe_artist = sanitize_filename(artist, max_length=60)
        safe_title = sanitize_filename(title, max_length=90)
        target_suffix = f"{safe_artist} - {safe_title}.{ext}".lower()

        if os.path.exists(output_dir):
            try:
                for existing_name in os.listdir(output_dir):
                    if existing_name.lower().endswith(target_suffix):
                        existing_full_path = os.path.join(output_dir, existing_name)
                        if os.path.isfile(existing_full_path) and os.path.getsize(existing_full_path) > 10240:
                            if status_callback:
                                status_callback(track_number, "Пропущен (уже скачан)")
                            return {
                                "status": "SKIPPED",
                                "filepath": existing_full_path,
                                "filename": existing_name
                            }
            except OSError:
                pass

        if status_callback:
            status_callback(track_number, "Поиск на YouTube...")

        # Temp download template in output directory
        temp_prefix = f"_tmp_{track_number}_{int(time.time())}"
        temp_outtmpl = os.path.join(output_dir, f"{temp_prefix}.%(ext)s")

        postprocessor = {
            "key": "FFmpegExtractAudio",
            "preferredcodec": ext,
        }
        if ext == "mp3":
            postprocessor["preferredquality"] = "320"

        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": temp_outtmpl,
            "postprocessors": [postprocessor],
            "extractor_args": {
                "youtube": {
                    "player_client": ["android"]
                }
            },
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            "nocheckcertificate": True,
        }

        # Cleaned title without remasters, editions or confusing punctuation
        clean_title = clean_track_title(title)

        # Multi-tier prioritized search queries:
        # 1. YouTube Official Audio with clean title
        # 2. YouTube Lyrics video (contains original studio audio, immune to Topic DRM/PO-token lock)
        # 3. YouTube Clean Title Audio
        # 4. YouTube Artist - Clean Title
        # 5. YouTube Raw Title (if cleaned title differs)
        # 6. YouTube Artist Title song (SafeSearch bypass)
        # 7. SoundCloud fallbacks
        queries = [
            f"ytsearch3:{artist} - {clean_title} official audio",
            f"ytsearch3:{artist} - {clean_title} lyrics",
            f"ytsearch3:{artist} - {clean_title} audio",
            f"ytsearch3:{artist} - {clean_title}",
        ]
        if clean_title.lower() != title.lower():
            queries.append(f"ytsearch3:{artist} - {title}")
        queries.extend([
            f"ytsearch3:{artist} {clean_title} song",
            f"scsearch2:{artist} - {clean_title}",
            f"scsearch2:{artist} {clean_title}"
        ])

        MIN_VALID_AUDIO_BYTES = 500 * 1024  # 500 KB threshold to reject age/block stubs
        download_success = False
        last_error = ""
        expected_temp_file = os.path.join(output_dir, f"{temp_prefix}.{ext}")
        queries_tried = []

        for q_idx, query in enumerate(queries):
            if is_cancelled and is_cancelled():
                return {"status": "CANCELLED", "filepath": "", "error": "Cancelled"}

            queries_tried.append(query)
            if status_callback:
                if q_idx == 0:
                    status_callback(track_number, "Поиск на YouTube...")
                elif "lyrics" in query:
                    status_callback(track_number, "Поиск по тексту песни...")
                elif "scsearch" in query:
                    status_callback(track_number, "Поиск в SoundCloud...")
                else:
                    status_callback(track_number, "Повторный поиск...")

            # Extract search candidates flat (up to 3 candidates per query)
            candidate_urls = []
            try:
                with yt_dlp.YoutubeDL({"quiet": True, "extract_flat": True, "no_warnings": True}) as flat_ydl:
                    info = flat_ydl.extract_info(query, download=False)
                    if info:
                        if "entries" in info:
                            for e in info.get("entries", []):
                                if e and e.get("id"):
                                    candidate_urls.append(f"https://www.youtube.com/watch?v={e['id']}" if "ytsearch" in query else e.get("url", ""))
                        elif info.get("id"):
                            candidate_urls.append(f"https://www.youtube.com/watch?v={info['id']}" if "ytsearch" in query else info.get("url", ""))
            except Exception as e:
                candidate_urls = [query]

            if not candidate_urls:
                candidate_urls = [query]

            # Try candidate URLs for this query
            for target_url in candidate_urls:
                if not target_url:
                    continue
                if is_cancelled and is_cancelled():
                    return {"status": "CANCELLED", "filepath": "", "error": "Cancelled"}

                try:
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        ydl.download([target_url])

                    # Audio integrity verification: file must exist and exceed 500 KB
                    if os.path.exists(expected_temp_file):
                        actual_size = os.path.getsize(expected_temp_file)
                        if actual_size >= MIN_VALID_AUDIO_BYTES:
                            download_success = True
                            break
                        else:
                            try:
                                os.remove(expected_temp_file)
                            except OSError:
                                pass
                            last_error = f"Файл-заглушка ({actual_size // 1024} КБ)"
                except Exception as e:
                    last_error = str(e)
                    logger.debug(f"Target '{target_url}' failed: {e}")
                    if os.path.exists(expected_temp_file):
                        try:
                            os.remove(expected_temp_file)
                        except OSError:
                            pass

            if download_success:
                break

        if not download_success or not os.path.exists(expected_temp_file):
            err_msg = last_error or "Трек не найден на YouTube / SoundCloud"
            if status_callback:
                status_callback(track_number, "Ошибка скачивания")

            # Log into in-memory session debug logger
            SessionDebugLogger.get_instance().log_error(
                track_number=track_number,
                artist=artist,
                title=title,
                queries_tried=queries_tried,
                error_message=err_msg,
                details=f"Target file: {target_filename}\nFormat: {audio_format}"
            )

            return {
                "status": "ERROR",
                "filepath": "",
                "error": err_msg
            }

        # 2. Tag file
        if status_callback:
            status_callback(track_number, "Вшивка тегов...")

        cover_bytes = fetch_cover_bytes(cover_url)
        try:
            tag_audio_file(
                expected_temp_file,
                artist=artist,
                title=title,
                album=album,
                track_number=track_number,
                cover_bytes=cover_bytes
            )
        except Exception as e:
            logger.warning(f"Tagging error for {expected_temp_file}: {e}")

        # 3. Rename temp file to final target file
        try:
            if os.path.exists(target_filepath):
                os.remove(target_filepath)
            os.rename(expected_temp_file, target_filepath)
        except Exception as e:
            # Fallback copy
            import shutil
            shutil.move(expected_temp_file, target_filepath)

        if status_callback:
            status_callback(track_number, "Готово")

        return {
            "status": "OK",
            "filepath": target_filepath,
            "filename": target_filename
        }

    def download_tracks_batch(
        self,
        tracks: List[Dict[str, str]],
        output_dir: str,
        audio_format: str = "mp3",
        include_number: bool = False,
        on_track_status: Optional[Callable[[int, str], None]] = None,
        on_progress_update: Optional[Callable[[int, int, Dict[str, str]], None]] = None,
        is_cancelled: Optional[Callable[[], bool]] = None,
        naming_template: str = ""
    ) -> List[Dict[str, str]]:
        """
        Coordinates multi-threaded batch downloading of tracks.
        Order of results strictly matches tracks input order.
        """
        os.makedirs(output_dir, exist_ok=True)
        total = len(tracks)
        results = [None] * total
        completed_count = 0

        indexed_tasks = list(enumerate(tracks, start=1))

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_num = {
                executor.submit(
                    self.download_single_track,
                    track_info=track,
                    track_number=num,
                    output_dir=output_dir,
                    audio_format=audio_format,
                    include_number=include_number,
                    total_tracks=total,
                    status_callback=on_track_status,
                    is_cancelled=is_cancelled,
                    naming_template=naming_template
                ): num
                for num, track in indexed_tasks
            }

            for future in as_completed(future_to_num):
                if is_cancelled and is_cancelled():
                    break

                num = future_to_num[future]
                idx = num - 1
                try:
                    res = future.result()
                except Exception as e:
                    res = {
                        "status": "ERROR",
                        "filepath": "",
                        "error": str(e)
                    }

                results[idx] = res
                completed_count += 1

                if on_progress_update:
                    on_progress_update(completed_count, total, res)

        # Fill cancelled slots
        for idx, item in enumerate(results):
            if item is None:
                results[idx] = {
                    "status": "CANCELLED",
                    "filepath": "",
                    "error": "Отменено пользователем"
                }

        return results
