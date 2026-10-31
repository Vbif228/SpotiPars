"""
In-memory session debug logger for SpotiPars.
Stores errors and failure diagnostic details strictly in RAM during the session.
Automatically clears on app exit.
"""

import threading
import datetime
from typing import List, Dict, Optional


class SessionDebugLogger:
    """Thread-safe in-memory session error logger."""

    _instance: Optional["SessionDebugLogger"] = None
    _lock = threading.Lock()

    def __init__(self):
        self._entries: List[Dict] = []
        self._lock = threading.Lock()

    @classmethod
    def get_instance(cls) -> "SessionDebugLogger":
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    def log_error(
        self,
        track_number: int,
        artist: str,
        title: str,
        queries_tried: List[str],
        error_message: str,
        details: str = ""
    ) -> None:
        """Records an error event in memory."""
        now = datetime.datetime.now().strftime("%H:%M:%S")
        entry = {
            "timestamp": now,
            "track_number": track_number,
            "artist": artist,
            "title": title,
            "queries": list(queries_tried),
            "error": error_message,
            "details": details,
        }
        with self._lock:
            self._entries.append(entry)

    def get_errors(self) -> List[Dict]:
        """Returns shallow copy of error entries."""
        with self._lock:
            return list(self._entries)

    def error_count(self) -> int:
        with self._lock:
            return len(self._entries)

    def clear(self) -> None:
        """Clears all logged session errors."""
        with self._lock:
            self._entries.clear()

    def export_text(self) -> str:
        """Formats all error logs as readable text report."""
        with self._lock:
            if not self._entries:
                return "Ошибок за текущую сессию не зафиксировано."

            lines = [
                "=" * 60,
                f"ЖУРНАЛ ОШИБОК СЕССИИ SPOTIPARS (Всего сбоев: {len(self._entries)})",
                f"Сформирован: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
                "=" * 60,
                ""
            ]

            for idx, e in enumerate(self._entries, start=1):
                lines.append(f"[{e['timestamp']}] Ошибка #{idx} | Трек №{e['track_number']:03d}")
                lines.append(f"  Исполнитель: {e['artist']}")
                lines.append(f"  Название:    {e['title']}")
                lines.append(f"  Причина:     {e['error']}")
                if e.get("queries"):
                    lines.append("  Поисковые запросы YouTube:")
                    for q in e["queries"]:
                        lines.append(f"    - {q}")
                if e.get("details"):
                    lines.append(f"  Технические детали:\n    {e['details'][:300]}")
                lines.append("-" * 60)

            return "\n".join(lines)
