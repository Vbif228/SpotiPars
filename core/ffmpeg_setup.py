"""
FFmpeg setup and path initialization.
Ensures ffmpeg and ffprobe are available in PATH for yt-dlp both in development
and when running inside a frozen PyInstaller executable.
"""

import os
import sys
import shutil
import logging

logger = logging.getLogger(__name__)


def ensure_ffmpeg_in_path() -> bool:
    """
    Checks for ffmpeg in standard locations and adds it to os.environ['PATH'].
    Returns True if ffmpeg is found and ready, False otherwise.
    """
    # 1. Check if already in system PATH
    if shutil.which("ffmpeg") and shutil.which("ffprobe"):
        logger.info("FFmpeg already present in system PATH.")
        return True

    # 2. Check if running inside PyInstaller bundle or next to executable
    candidate_dirs = []
    if getattr(sys, "frozen", False):
        candidate_dirs.append(getattr(sys, "_MEIPASS", ""))
        candidate_dirs.append(os.path.join(getattr(sys, "_MEIPASS", ""), "bin"))
        candidate_dirs.append(os.path.dirname(sys.executable))
        candidate_dirs.append(os.path.join(os.path.dirname(sys.executable), "bin"))
    else:
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidate_dirs.append(os.path.join(project_root, "bin"))

    for d in candidate_dirs:
        if d and os.path.isdir(d):
            ffmpeg_exe = os.path.join(d, "ffmpeg.exe")
            if os.path.exists(ffmpeg_exe):
                if d not in os.environ.get("PATH", ""):
                    os.environ["PATH"] = d + os.pathsep + os.environ.get("PATH", "")
                logger.info(f"Added bundled FFmpeg directory to PATH: {d}")
                return True

    # 3. Fallback to static_ffmpeg if available
    try:
        import static_ffmpeg
        static_ffmpeg.add_paths()
        if shutil.which("ffmpeg"):
            logger.info("Initialized FFmpeg via static-ffmpeg.")
            return True
    except Exception as e:
        logger.warning(f"static-ffmpeg initialization error: {e}")

    return shutil.which("ffmpeg") is not None
