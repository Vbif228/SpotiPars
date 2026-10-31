"""
SpotiPars - Desktop Spotify Track Exporter.
Entry point for the application.
"""

import os
import sys

# Ensure proper path resolution when running frozen (PyInstaller) or source
if getattr(sys, "frozen", False):
    APP_DIR = sys._MEIPASS
else:
    APP_DIR = os.path.dirname(os.path.abspath(__file__))

if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

# Enable High DPI scaling and Taskbar AppID on Windows
if sys.platform == "win32":
    try:
        from ctypes import windll
        # Set AppUserModelID so Windows taskbar displays the native high-res icon
        windll.shell32.SetCurrentProcessExplicitAppUserModelID("spotipars.desktop.exporter.v1")
        # Set DPI awareness: 1 = Process_System_DPI_Aware, 2 = Process_Per_Monitor_DPI_Aware
        try:
            windll.shcore.SetProcessDpiAwareness(1)
        except Exception:
            windll.user32.SetProcessDPIAware()
    except Exception:
        pass

from ui.app import run_app


def main():
    run_app()


if __name__ == "__main__":
    main()
