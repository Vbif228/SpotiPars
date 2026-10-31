"""
Modern Desktop GUI for SpotiPars using CustomTkinter with Spotify Dark Theme.
Supports Spotify link extraction, CSV/TXT export, and audio downloading
with yt-dlp, FFmpeg (MP3 320k / FLAC), and mutagen metadata tagging.
"""

import os
import sys
import webbrowser
from datetime import datetime
import tkinter as tk
from tkinter import ttk, messagebox, filedialog, simpledialog
import threading
from typing import List, Dict, Optional

import customtkinter as ctk
from PIL import Image, ImageTk

from core.scraper import extract_track_ids, SpotifyScraper
from core.exporter import export_to_csv, export_to_txt, format_tracks_as_text
from core.downloader import AudioDownloader, sanitize_filename
from core.ffmpeg_setup import ensure_ffmpeg_in_path
from core.debug_logger import SessionDebugLogger

# Spotify Color Palette
COLOR_BG = "#121212"
COLOR_CARD = "#181818"
COLOR_CARD_SECONDARY = "#222222"
COLOR_BORDER = "#2A2A2A"
COLOR_GREEN = "#1DB954"
COLOR_GREEN_HOVER = "#1ED760"
COLOR_GREEN_ACTIVE = "#169C46"
COLOR_TEXT_PRIMARY = "#FFFFFF"
COLOR_TEXT_SECONDARY = "#B3B3B3"
COLOR_TEXT_MUTED = "#727272"
COLOR_ROW_EVEN = "#181818"
COLOR_ROW_ODD = "#202020"
COLOR_DANGER_TEXT = "#FF5555"
COLOR_DANGER_HOVER = "#3B1E22"
COLOR_WARNING = "#E5A93C"


class ManualInputDialog(ctk.CTkToplevel):
    """Dialog for manual input/pasting of Spotify links."""
    def __init__(self, parent, on_submit):
        super().__init__(parent)
        self.title("Ручной ввод ссылок Spotify")
        self.geometry("620x460")
        self.minsize(500, 350)
        self.configure(fg_color=COLOR_BG)
        self.on_submit = on_submit
        self.transient(parent)
        self.grab_set()

        # Center dialog relative to parent
        self.update_idletasks()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        px = parent.winfo_rootx()
        py = parent.winfo_rooty()
        x = px + max(0, (pw - 620) // 2)
        y = py + max(0, (ph - 460) // 2)
        self.geometry(f"+{x}+{y}")

        # Header
        lbl = ctk.CTkLabel(
            self,
            text="Вставьте ссылки на треки Spotify (по одной на строке или списком):",
            font=("Segoe UI", 13, "bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        lbl.pack(padx=20, pady=(16, 8), anchor="w")

        # Text box
        self.txt = ctk.CTkTextbox(
            self,
            fg_color=COLOR_CARD,
            text_color=COLOR_TEXT_PRIMARY,
            border_color=COLOR_BORDER,
            border_width=1,
            corner_radius=8,
            font=("Consolas", 12)
        )
        self.txt.pack(padx=20, pady=8, fill="both", expand=True)

        # Buttons
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(padx=20, pady=(8, 16), fill="x")

        btn_cancel = ctk.CTkButton(
            btn_frame,
            text="Отмена",
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_BORDER,
            text_color=COLOR_TEXT_SECONDARY,
            width=100,
            height=36,
            command=self.destroy
        )
        btn_cancel.pack(side="right", padx=(10, 0))

        btn_ok = ctk.CTkButton(
            btn_frame,
            text="Обработать ссылки",
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            text_color="#000000",
            font=("Segoe UI", 12, "bold"),
            height=36,
            command=self._confirm
        )
        btn_ok.pack(side="right")

    def _confirm(self):
        text = self.txt.get("1.0", "end")
        self.destroy()
        if self.on_submit:
            self.on_submit(text)


class ErrorLogDialog(ctk.CTkToplevel):
    """Dialog for viewing and copying the in-memory session error log."""
    def __init__(self, parent, on_clear_callback=None):
        super().__init__(parent)
        self.title("Журнал ошибок текущей сессии")
        self.geometry("740x520")
        self.minsize(580, 400)
        self.configure(fg_color=COLOR_BG)
        self.on_clear_callback = on_clear_callback
        self.transient(parent)
        self.grab_set()

        # Center dialog relative to parent
        self.update_idletasks()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        px = parent.winfo_rootx()
        py = parent.winfo_rooty()
        x = px + max(0, (pw - 740) // 2)
        y = py + max(0, (ph - 520) // 2)
        self.geometry(f"+{x}+{y}")

        # Header Frame
        hdr = ctk.CTkFrame(self, fg_color="transparent")
        hdr.pack(fill="x", padx=20, pady=(16, 6))

        lbl_title = ctk.CTkLabel(
            hdr,
            text="Журнал ошибок текущей сессии",
            font=("Segoe UI", 14, "bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        lbl_title.pack(anchor="w")

        lbl_sub = ctk.CTkLabel(
            hdr,
            text="Записи хранятся исключительно в оперативной памяти и автоматически очищаются при закрытии программы.",
            font=("Segoe UI", 11),
            text_color=COLOR_TEXT_SECONDARY
        )
        lbl_sub.pack(anchor="w", pady=(2, 0))

        # Text Box
        self.txt = ctk.CTkTextbox(
            self,
            fg_color=COLOR_CARD,
            text_color=COLOR_TEXT_PRIMARY,
            border_color=COLOR_BORDER,
            border_width=1,
            corner_radius=8,
            font=("Consolas", 11)
        )
        self.txt.pack(padx=20, pady=8, fill="both", expand=True)
        self._refresh_content()

        # Bottom Buttons
        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(padx=20, pady=(8, 16), fill="x")

        self.btn_copy = ctk.CTkButton(
            btn_frame,
            text="📋 Скопировать отчёт",
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            text_color="#000000",
            font=("Segoe UI", 12, "bold"),
            height=36,
            command=self._copy_log
        )
        self.btn_copy.pack(side="left")

        self.btn_clear = ctk.CTkButton(
            btn_frame,
            text="🗑️ Очистить журнал",
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_DANGER_HOVER,
            text_color=COLOR_DANGER_TEXT,
            font=("Segoe UI", 12),
            height=36,
            command=self._clear_log
        )
        self.btn_clear.pack(side="left", padx=(10, 0))

        btn_close = ctk.CTkButton(
            btn_frame,
            text="Закрыть",
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_BORDER,
            text_color=COLOR_TEXT_SECONDARY,
            width=100,
            height=36,
            command=self.destroy
        )
        btn_close.pack(side="right")

    def _refresh_content(self):
        text = SessionDebugLogger.get_instance().export_text()
        self.txt.delete("1.0", "end")
        self.txt.insert("1.0", text)

    def _copy_log(self):
        text = self.txt.get("1.0", "end").strip()
        self.clipboard_clear()
        self.clipboard_append(text)
        self.btn_copy.configure(text="✓ Скопировано!")
        self.after(2000, lambda: self.btn_copy.configure(text="📋 Скопировать отчёт"))

    def _clear_log(self):
        SessionDebugLogger.get_instance().clear()
        self._refresh_content()
        if self.on_clear_callback:
            self.on_clear_callback()


class SpotiParsApp(ctk.CTk):
    """Main application window for SpotiPars."""

    def __init__(self):
        super().__init__()

        # Ensure FFmpeg is available
        ensure_ffmpeg_in_path()

        # Window configuration
        self.title("SpotiPars — Экспорт и скачивание треков Spotify")
        self.geometry("980x740")
        self.minsize(840, 600)
        self.configure(fg_color=COLOR_BG)

        # Set application icon if available
        self._set_app_icon()

        # State
        self.scraper = SpotifyScraper(timeout=10, max_workers=18)
        self.downloader = AudioDownloader(max_workers=4)
        self.tracks: List[Dict[str, str]] = []
        self.last_dest_folder: str = ""
        self._is_fetching = False
        self._cancel_flag = False
        self._is_downloading = False
        self._cancel_download_flag = False
        self._worker_thread: Optional[threading.Thread] = None
        self._download_thread: Optional[threading.Thread] = None

        # Build UI layout
        self._create_header()
        self._create_action_bar()
        self._create_download_bar()
        self._create_progress_panel()
        self._create_table_view()
        self._create_export_bar()

        # Handle window close
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _set_app_icon(self):
        """Sets application window icon with multi-size high-res support."""
        try:
            if getattr(sys, "frozen", False):
                base_dir = getattr(sys, "_MEIPASS", os.path.abspath("."))
            else:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

            ico_path = os.path.join(base_dir, "assets", "icon.ico")
            png_path = os.path.join(base_dir, "assets", "icon.png")

            # 1. Windows iconbitmap
            if os.path.exists(ico_path):
                self.iconbitmap(ico_path)

            # 2. iconphoto for pixel-perfect titlebar & alt-tab
            if os.path.exists(png_path):
                master_img = Image.open(png_path).convert("RGBA")
                self._icon_photos = [
                    ImageTk.PhotoImage(master_img.resize((256, 256), Image.Resampling.LANCZOS)),
                    ImageTk.PhotoImage(master_img.resize((64, 64), Image.Resampling.LANCZOS)),
                    ImageTk.PhotoImage(master_img.resize((32, 32), Image.Resampling.LANCZOS)),
                    ImageTk.PhotoImage(master_img.resize((16, 16), Image.Resampling.LANCZOS)),
                ]
                self.iconphoto(False, *self._icon_photos)
        except Exception:
            pass

    def _create_header(self):
        """Header with logo and status badge."""
        header_frame = ctk.CTkFrame(self, fg_color="transparent")
        header_frame.pack(fill="x", padx=24, pady=(16, 10))

        # Left side: Brand badge + Title + Subtitle
        left_box = ctk.CTkFrame(header_frame, fg_color="transparent")
        left_box.pack(side="left", fill="y")

        title_box = ctk.CTkFrame(left_box, fg_color="transparent")
        title_box.pack(anchor="w")

        # High-res Spotify Logo image in header
        if getattr(sys, "frozen", False):
            base_dir = getattr(sys, "_MEIPASS", os.path.abspath("."))
        else:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        png_path = os.path.join(base_dir, "assets", "icon.png")

        if os.path.exists(png_path):
            try:
                logo_img = Image.open(png_path).convert("RGBA")
                self.header_logo_ctk = ctk.CTkImage(
                    light_image=logo_img,
                    dark_image=logo_img,
                    size=(30, 30)
                )
                logo_widget = ctk.CTkLabel(title_box, text="", image=self.header_logo_ctk)
                logo_widget.pack(side="left", padx=(0, 10))
            except Exception:
                logo_widget = ctk.CTkLabel(
                    title_box,
                    text="♫",
                    font=("Segoe UI", 22, "bold"),
                    text_color=COLOR_GREEN
                )
                logo_widget.pack(side="left", padx=(0, 8))
        else:
            logo_widget = ctk.CTkLabel(
                title_box,
                text="♫",
                font=("Segoe UI", 22, "bold"),
                text_color=COLOR_GREEN
            )
            logo_widget.pack(side="left", padx=(0, 8))

        app_title = ctk.CTkLabel(
            title_box,
            text="SpotiPars",
            font=("Segoe UI", 22, "bold"),
            text_color=COLOR_TEXT_PRIMARY
        )
        app_title.pack(side="left")

        ver_badge = ctk.CTkLabel(
            title_box,
            text="v2.0",
            font=("Segoe UI", 11, "bold"),
            text_color=COLOR_GREEN,
            fg_color="#132B1B",
            corner_radius=6,
            padx=8,
            pady=2
        )
        ver_badge.pack(side="left", padx=(10, 0))

        subtitle = ctk.CTkLabel(
            left_box,
            text="Экспорт и скачивание треков из Spotify (MP3 320k / FLAC) с обложками и тегами",
            font=("Segoe UI", 12),
            text_color=COLOR_TEXT_SECONDARY
        )
        subtitle.pack(anchor="w", pady=(2, 0))

        # Right side: Stats chips & Debug Log button
        self.btn_debug_log = ctk.CTkButton(
            header_frame,
            text="📄 Журнал ошибок (0)",
            font=("Segoe UI", 11, "bold"),
            fg_color=COLOR_CARD,
            hover_color=COLOR_CARD_SECONDARY,
            border_color=COLOR_BORDER,
            border_width=1,
            text_color=COLOR_TEXT_SECONDARY,
            height=32,
            corner_radius=8,
            command=self._open_debug_log
        )
        self.btn_debug_log.pack(side="right", padx=(10, 0), pady=2)

        self.stats_frame = ctk.CTkFrame(header_frame, fg_color=COLOR_CARD, corner_radius=10, border_color=COLOR_BORDER, border_width=1)
        self.stats_frame.pack(side="right", padx=(10, 0), pady=2)

        self.lbl_stat_count = ctk.CTkLabel(
            self.stats_frame,
            text="Треков: 0",
            font=("Segoe UI", 12, "bold"),
            text_color=COLOR_TEXT_PRIMARY,
            padx=14,
            pady=6
        )
        self.lbl_stat_count.pack(side="left")

        self.lbl_stat_status = ctk.CTkLabel(
            self.stats_frame,
            text="• Готов",
            font=("Segoe UI", 12, "bold"),
            text_color=COLOR_GREEN,
            padx=14,
            pady=6
        )
        self.lbl_stat_status.pack(side="left")

    def _create_action_bar(self):
        """Action bar with primary CTA button and secondary actions."""
        action_card = ctk.CTkFrame(
            self,
            fg_color=COLOR_CARD,
            corner_radius=12,
            border_color=COLOR_BORDER,
            border_width=1
        )
        action_card.pack(fill="x", padx=24, pady=(0, 10))

        inner = ctk.CTkFrame(action_card, fg_color="transparent")
        inner.pack(fill="x", padx=16, pady=10)

        # Primary Big Button: Paste from Clipboard
        self.btn_paste = ctk.CTkButton(
            inner,
            text="📥  Вставить треки из буфера обмена",
            font=("Segoe UI", 13, "bold"),
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            text_color="#000000",
            height=40,
            corner_radius=20,
            command=self._on_paste_clipboard
        )
        self.btn_paste.pack(side="left", padx=(0, 10), fill="x", expand=True)

        # Secondary Button: Manual text input
        self.btn_manual = ctk.CTkButton(
            inner,
            text="✏️  Ввести вручную",
            font=("Segoe UI", 12),
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_BORDER,
            text_color=COLOR_TEXT_PRIMARY,
            height=40,
            corner_radius=20,
            width=150,
            command=self._on_manual_input
        )
        self.btn_manual.pack(side="left", padx=(0, 10))

        # Clear button
        self.btn_clear = ctk.CTkButton(
            inner,
            text="🗑️  Очистить",
            font=("Segoe UI", 12),
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_DANGER_HOVER,
            text_color=COLOR_DANGER_TEXT,
            height=40,
            corner_radius=20,
            width=110,
            command=self._on_clear_clicked
        )
        self.btn_clear.pack(side="right")

    def _create_download_bar(self):
        """Audio download controls toolbar with refined modern Spotify-style layout."""
        dl_card = ctk.CTkFrame(
            self,
            fg_color=COLOR_CARD,
            corner_radius=12,
            border_color=COLOR_BORDER,
            border_width=1
        )
        dl_card.pack(fill="x", padx=24, pady=(0, 10))

        card_content = ctk.CTkFrame(dl_card, fg_color="transparent")
        card_content.pack(fill="x", padx=16, pady=10)

        # Row 1: Options & Parameters
        row1 = ctk.CTkFrame(card_content, fg_color="transparent")
        row1.pack(fill="x", pady=(0, 8))

        # Format label
        lbl_fmt = ctk.CTkLabel(
            row1,
            text="Формат:",
            font=("Segoe UI", 11, "bold"),
            text_color=COLOR_TEXT_MUTED
        )
        lbl_fmt.pack(side="left", padx=(0, 8))

        # Rectangular format buttons with 6px radius matching screenshot
        self.format_selector = ctk.CTkSegmentedButton(
            row1,
            values=["MP3 (320 kbps)", "FLAC"],
            selected_color=COLOR_GREEN,
            selected_hover_color=COLOR_GREEN_HOVER,
            unselected_color=COLOR_CARD_SECONDARY,
            unselected_hover_color="#2A2A2A",
            text_color="#FFFFFF",
            font=("Segoe UI", 11, "bold"),
            corner_radius=6,
            border_width=1,
            height=30
        )
        self.format_selector.set("MP3 (320 kbps)")
        self.format_selector.pack(side="left", padx=(0, 14))

        # Separator 1
        sep1 = ctk.CTkFrame(row1, width=1, height=20, fg_color=COLOR_BORDER)
        sep1.pack(side="left", padx=(0, 14))

        # Naming template label
        lbl_naming = ctk.CTkLabel(
            row1,
            text="Имена файлов:",
            font=("Segoe UI", 11, "bold"),
            text_color=COLOR_TEXT_MUTED
        )
        lbl_naming.pack(side="left", padx=(0, 8))

        # Naming template dropdown
        self.opt_naming = ctk.CTkOptionMenu(
            row1,
            values=[
                "Исполнитель - Название",
                "001. Исполнитель - Название",
                "001 - Исполнитель - Название"
            ],
            fg_color=COLOR_CARD_SECONDARY,
            button_color=COLOR_CARD_SECONDARY,
            button_hover_color=COLOR_BORDER,
            dropdown_fg_color=COLOR_CARD,
            dropdown_hover_color=COLOR_CARD_SECONDARY,
            dropdown_text_color=COLOR_TEXT_PRIMARY,
            text_color=COLOR_TEXT_PRIMARY,
            font=("Segoe UI", 11),
            dropdown_font=("Segoe UI", 11),
            corner_radius=6,
            height=30,
            width=220
        )
        self.opt_naming.set("Исполнитель - Название")
        self.opt_naming.pack(side="left", padx=(0, 14))

        # Separator 2
        sep2 = ctk.CTkFrame(row1, width=1, height=20, fg_color=COLOR_BORDER)
        sep2.pack(side="left", padx=(0, 14))

        # Playlist Subfolder checkbox
        self.chk_subfolder = ctk.CTkCheckBox(
            row1,
            text="📁 Подпапка для плейлиста",
            font=("Segoe UI", 11),
            text_color=COLOR_TEXT_PRIMARY,
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            checkmark_color="#000000",
            border_color="#3E3E3E",
            border_width=2,
            checkbox_width=18,
            checkbox_height=18,
            corner_radius=4
        )
        self.chk_subfolder.deselect()
        self.chk_subfolder.pack(side="left")

        # Row 2: Info hint & Main Action Buttons
        row2 = ctk.CTkFrame(card_content, fg_color="transparent")
        row2.pack(fill="x")

        # Hint text
        lbl_hint = ctk.CTkLabel(
            row2,
            text="💡 Умный пропуск повторов • Вшивка обложек и ID3/FLAC метаданных",
            font=("Segoe UI", 11),
            text_color=COLOR_TEXT_MUTED
        )
        lbl_hint.pack(side="left", anchor="w")

        # Download button
        self.btn_download = ctk.CTkButton(
            row2,
            text="⚡  Скачать все треки",
            font=("Segoe UI", 13, "bold"),
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            text_color="#000000",
            height=34,
            corner_radius=8,
            width=185,
            command=self._on_download_clicked
        )
        self.btn_download.pack(side="right")

        # Stop button (initially disabled)
        self.btn_stop_download = ctk.CTkButton(
            row2,
            text="⏹  Остановить",
            font=("Segoe UI", 12),
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_DANGER_HOVER,
            text_color=COLOR_DANGER_TEXT,
            height=34,
            corner_radius=8,
            width=110,
            state="disabled",
            command=self._on_stop_download_clicked
        )
        self.btn_stop_download.pack(side="right", padx=(0, 10))

    def _create_progress_panel(self):
        """Smooth progress bar and status text."""
        prog_frame = ctk.CTkFrame(self, fg_color="transparent")
        prog_frame.pack(fill="x", padx=24, pady=(0, 8))

        # Status text row
        status_row = ctk.CTkFrame(prog_frame, fg_color="transparent")
        status_row.pack(fill="x", pady=(0, 4))

        # Pack percent on the right first so it is never pushed off by long status text
        self.lbl_progress_percent = ctk.CTkLabel(
            status_row,
            text="",
            font=("Segoe UI", 12, "bold"),
            text_color=COLOR_GREEN
        )
        self.lbl_progress_percent.pack(side="right", padx=(8, 0))

        self.lbl_status = ctk.CTkLabel(
            status_row,
            text="Скопируйте треки в Spotify (Ctrl+A ➔ Ctrl+C) и нажмите «Вставить треки из буфера обмена»",
            font=("Segoe UI", 12),
            text_color=COLOR_TEXT_SECONDARY,
            anchor="w"
        )
        self.lbl_status.pack(side="left", fill="x", expand=True)

        # Progress bar
        self.progress_bar = ctk.CTkProgressBar(
            prog_frame,
            height=6,
            corner_radius=3,
            fg_color=COLOR_CARD_SECONDARY,
            progress_color=COLOR_GREEN
        )
        self.progress_bar.pack(fill="x")
        self.progress_bar.set(0.0)

    def _create_table_view(self):
        """Table preview styled with Spotify dark theme."""
        table_container = ctk.CTkFrame(
            self,
            fg_color=COLOR_CARD,
            corner_radius=12,
            border_color=COLOR_BORDER,
            border_width=1
        )
        table_container.pack(fill="both", expand=True, padx=24, pady=(0, 10))

        # Configure ttk.Treeview style
        style = ttk.Style()
        style.theme_use("clam")

        # Colors for Treeview
        style.configure(
            "Spotify.Treeview",
            background=COLOR_CARD,
            fieldbackground=COLOR_CARD,
            foreground=COLOR_TEXT_PRIMARY,
            rowheight=30,
            font=("Segoe UI", 11),
            borderwidth=0,
            relief="flat"
        )
        style.map(
            "Spotify.Treeview",
            background=[("selected", COLOR_GREEN)],
            foreground=[("selected", "#000000")]
        )

        style.configure(
            "Spotify.Treeview.Heading",
            background=COLOR_CARD_SECONDARY,
            foreground=COLOR_TEXT_PRIMARY,
            relief="flat",
            font=("Segoe UI", 11, "bold"),
            padding=(8, 6)
        )
        style.map(
            "Spotify.Treeview.Heading",
            background=[("active", "#2C2C2C")]
        )

        # Custom dark Scrollbar styles (Vertical and Horizontal)
        style.configure(
            "Spotify.Vertical.TScrollbar",
            background="#3A3A3A",
            troughcolor="#181818",
            arrowcolor=COLOR_TEXT_SECONDARY,
            relief="flat",
            borderwidth=0
        )
        style.map(
            "Spotify.Vertical.TScrollbar",
            background=[("active", "#555555")]
        )

        style.configure(
            "Spotify.Horizontal.TScrollbar",
            background="#3A3A3A",
            troughcolor="#181818",
            arrowcolor=COLOR_TEXT_SECONDARY,
            relief="flat",
            borderwidth=0
        )
        style.map(
            "Spotify.Horizontal.TScrollbar",
            background=[("active", "#555555")]
        )

        # Configure grid on table container for dual scrollbars
        table_container.grid_rowconfigure(0, weight=1)
        table_container.grid_columnconfigure(0, weight=1)

        # Table Treeview
        columns = ("num", "artist", "title", "status")
        self.tree = ttk.Treeview(
            table_container,
            columns=columns,
            show="headings",
            style="Spotify.Treeview",
            selectmode="extended"
        )

        self.tree.heading("num", text="№", anchor="center")
        self.tree.heading("artist", text="Исполнитель", anchor="w")
        self.tree.heading("title", text="Название трека", anchor="w")
        self.tree.heading("status", text="Статус", anchor="center")

        self.tree.column("num", width=48, minwidth=40, stretch=False, anchor="center")
        self.tree.column("artist", width=250, minwidth=160, stretch=True, anchor="w")
        self.tree.column("title", width=400, minwidth=200, stretch=True, anchor="w")
        self.tree.column("status", width=260, minwidth=240, stretch=False, anchor="center")

        # Alternating and status row colors
        self.tree.tag_configure("even", background=COLOR_ROW_EVEN)
        self.tree.tag_configure("odd", background=COLOR_ROW_ODD)
        self.tree.tag_configure("done", foreground=COLOR_GREEN)
        self.tree.tag_configure("active", foreground=COLOR_WARNING)
        self.tree.tag_configure("skipped", foreground=COLOR_TEXT_SECONDARY)
        self.tree.tag_configure("error", foreground=COLOR_DANGER_TEXT)

        # Vertical & Horizontal Scrollbars (Sliders)
        v_scrollbar = ttk.Scrollbar(
            table_container,
            orient="vertical",
            command=self.tree.yview,
            style="Spotify.Vertical.TScrollbar"
        )
        h_scrollbar = ttk.Scrollbar(
            table_container,
            orient="horizontal",
            command=self.tree.xview,
            style="Spotify.Horizontal.TScrollbar"
        )
        self.tree.configure(yscrollcommand=v_scrollbar.set, xscrollcommand=h_scrollbar.set)

        self.tree.grid(row=0, column=0, sticky="nsew", padx=(8, 0), pady=(8, 0))
        v_scrollbar.grid(row=0, column=1, sticky="ns", padx=(0, 6), pady=(8, 0))
        h_scrollbar.grid(row=1, column=0, sticky="ew", padx=(8, 0), pady=(2, 6))

        # Bind events
        self.tree.bind("<Double-1>", self._on_tree_double_click)
        self.tree.bind("<Button-3>", self._on_tree_right_click)

        # Context Menu
        self.context_menu = tk.Menu(self, tearoff=0, bg=COLOR_CARD_SECONDARY, fg=COLOR_TEXT_PRIMARY, activebackground=COLOR_GREEN, activeforeground="#000000")
        self.context_menu.add_command(label="Копировать (Исполнитель - Название)", command=self._copy_selected_track)
        self.context_menu.add_command(label="Копировать ссылку на Spotify", command=self._copy_selected_url)
        self.context_menu.add_command(label="Открыть в браузере", command=self._open_selected_in_browser)
        self.context_menu.add_separator()
        self.context_menu.add_command(label="🔄 Повторить скачивание трека", command=self._retry_selected_download)
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Удалить из списка", command=self._delete_selected_rows)

    def _create_export_bar(self):
        """Bottom export bar with CSV and TXT buttons and tip."""
        bottom_frame = ctk.CTkFrame(self, fg_color="transparent")
        bottom_frame.pack(fill="x", padx=24, pady=(0, 14))

        # Left side: Format tip
        tip_frame = ctk.CTkFrame(bottom_frame, fg_color="transparent")
        tip_frame.pack(side="left", fill="y")

        lbl_tip = ctk.CTkLabel(
            tip_frame,
            text="⚡ CSV сохраняется в UTF-8-BOM с разделителем «;» (идеально для Microsoft Excel)",
            font=("Segoe UI", 11),
            text_color=COLOR_TEXT_MUTED
        )
        lbl_tip.pack(anchor="w")

        # Right side: Export buttons
        btn_box = ctk.CTkFrame(bottom_frame, fg_color="transparent")
        btn_box.pack(side="right")

        self.btn_copy_all = ctk.CTkButton(
            btn_box,
            text="📋  Копировать список",
            font=("Segoe UI", 12),
            fg_color=COLOR_CARD,
            hover_color=COLOR_CARD_SECONDARY,
            border_color=COLOR_BORDER,
            border_width=1,
            text_color=COLOR_TEXT_PRIMARY,
            height=36,
            corner_radius=8,
            command=self._on_copy_all_clicked
        )
        self.btn_copy_all.pack(side="left", padx=(0, 10))

        self.btn_save_txt = ctk.CTkButton(
            btn_box,
            text="📄  Сохранить в TXT",
            font=("Segoe UI", 12, "bold"),
            fg_color=COLOR_CARD_SECONDARY,
            hover_color=COLOR_BORDER,
            text_color=COLOR_TEXT_PRIMARY,
            height=36,
            corner_radius=8,
            command=self._on_save_txt_clicked
        )
        self.btn_save_txt.pack(side="left", padx=(0, 10))

        self.btn_save_csv = ctk.CTkButton(
            btn_box,
            text="💾  Сохранить в CSV",
            font=("Segoe UI", 12, "bold"),
            fg_color=COLOR_GREEN,
            hover_color=COLOR_GREEN_HOVER,
            text_color="#000000",
            height=36,
            corner_radius=8,
            command=self._on_save_csv_clicked
        )
        self.btn_save_csv.pack(side="left")

    # ------------------ Action Handlers ------------------

    def _on_paste_clipboard(self):
        """Fetches clipboard content and starts extraction."""
        if self._is_fetching or self._is_downloading:
            messagebox.showinfo("Операция активна", "Дождитесь окончания текущей операции.")
            return

        try:
            clipboard_text = self.clipboard_get()
        except tk.TclError:
            clipboard_text = ""

        if not clipboard_text or not clipboard_text.strip():
            messagebox.showwarning(
                "Буфер обмена пуст",
                "В буфере обмена не найдено текста.\n\n"
                "Инструкция:\n"
                "1. В приложении Spotify откройте плейлист или альбом\n"
                "2. Выделите треки (нажмите Ctrl+A)\n"
                "3. Скопируйте ссылки (нажмите Ctrl+C)\n"
                "4. Нажмите «Вставить треки из буфера обмена»"
            )
            return

        self._process_raw_text(clipboard_text)

    def _on_manual_input(self):
        """Opens dialog for pasting links manually."""
        if self._is_fetching or self._is_downloading:
            messagebox.showinfo("Операция активна", "Дождитесь окончания текущей операции.")
            return

        ManualInputDialog(self, on_submit=self._process_raw_text)

    def _process_raw_text(self, text: str):
        """Extracts track IDs and starts background fetch."""
        track_ids = extract_track_ids(text)
        if not track_ids:
            messagebox.showwarning(
                "Ссылки не найдены",
                "В предоставленном тексте не обнаружено ссылок на треки Spotify вида:\n"
                "https://open.spotify.com/track/..."
            )
            return

        self._start_fetching(track_ids)

    def _start_fetching(self, track_ids: List[str]):
        """Initiates concurrent fetching in a worker thread."""
        self._is_fetching = True
        self._cancel_flag = False
        self.tracks = []
        self._clear_table()

        total = len(track_ids)
        self.lbl_status.configure(
            text=f"Обработка ссылок: 0 из {total}...",
            text_color=COLOR_TEXT_PRIMARY
        )
        self.lbl_progress_percent.configure(text="0%")
        self.progress_bar.set(0.0)
        self.lbl_stat_status.configure(text="• Загрузка...", text_color=COLOR_WARNING)
        self.lbl_stat_count.configure(text=f"Найдено: {total}")

        # Disable buttons during fetch
        self._set_ui_busy(True)

        # Launch worker
        def worker():
            def on_progress(completed, total_items, item_data):
                self.after(0, self._on_item_fetched, completed, total_items, item_data)

            scraper_instance = SpotifyScraper(timeout=10, max_workers=18)
            results = scraper_instance.fetch_tracks_batch(
                track_ids,
                progress_callback=on_progress,
                is_cancelled=lambda: self._cancel_flag
            )

            self.after(0, self._on_fetching_complete, results)

        self._worker_thread = threading.Thread(target=worker, daemon=True)
        self._worker_thread.start()

    def _on_item_fetched(self, completed: int, total: int, item: Dict[str, str]):
        """Called safely on main thread when a single track finishes."""
        ratio = completed / total if total > 0 else 1.0
        percent = int(ratio * 100)

        self.progress_bar.set(ratio)
        self.lbl_progress_percent.configure(text=f"{percent}%")
        self.lbl_status.configure(
            text=f"Загрузка треков: {completed} из {total} ({percent}%)... Последний: {item.get('artist', '')} - {item.get('title', '')}"
        )

    def _on_fetching_complete(self, results: List[Dict[str, str]]):
        """Called safely on main thread when entire batch finishes."""
        self._is_fetching = False
        self.tracks = results

        self._set_ui_busy(False)
        self._populate_table(self.tracks)

        success_count = sum(1 for t in self.tracks if t.get("status") == "OK")
        total = len(self.tracks)

        self.progress_bar.set(1.0)
        self.lbl_progress_percent.configure(text="100%")
        self.lbl_status.configure(
            text=f"Готово! Загружено {success_count} из {total} треков. Теперь вы можете сохранить или скачать аудио.",
            text_color=COLOR_GREEN
        )
        self.lbl_stat_status.configure(text="• Готов", text_color=COLOR_GREEN)
        self.lbl_stat_count.configure(text=f"Треков: {total}")

    def _populate_table(self, tracks: List[Dict[str, str]]):
        """Fills treeview with tracks keeping strict original order."""
        self._clear_table()
        for idx, track in enumerate(tracks, start=1):
            tag = "even" if idx % 2 == 0 else "odd"
            status = track.get("status", "В очереди")
            if status == "OK":
                status = "Готов"

            self.tree.insert(
                "",
                "end",
                iid=str(idx - 1),
                values=(
                    str(idx),
                    track.get("artist", ""),
                    track.get("title", ""),
                    status
                ),
                tags=(tag,)
            )

    def _clear_table(self):
        """Clears all rows from Treeview."""
        for item in self.tree.get_children():
            self.tree.delete(item)

    def _on_clear_clicked(self):
        """Resets application state."""
        if self._is_fetching:
            self._cancel_flag = True
        if self._is_downloading:
            self._cancel_download_flag = True

        self.tracks = []
        self._clear_table()
        self.progress_bar.set(0.0)
        self.lbl_progress_percent.configure(text="")
        self.lbl_status.configure(
            text="Список очищен. Скопируйте треки в Spotify (Ctrl+A ➔ Ctrl+C) и нажмите кнопку.",
            text_color=COLOR_TEXT_SECONDARY
        )
        self.lbl_stat_count.configure(text="Треков: 0")
        self.lbl_stat_status.configure(text="• Готов", text_color=COLOR_GREEN)
        self._set_ui_busy(False)

    # ------------------ Audio Download Handlers ------------------

    def _on_download_clicked(self):
        """Initiates batch download of all tracks to audio files."""
        if not self.tracks:
            messagebox.showinfo("Список пуст", "Сначала вставьте треки из Spotify.")
            return

        # Choose destination folder
        dest_folder = filedialog.askdirectory(title="Выберите папку для сохранения музыки")
        if not dest_folder:
            return

        fmt_raw = self.format_selector.get()
        audio_format = "flac" if "FLAC" in fmt_raw.upper() else "mp3"
        naming_template = self.opt_naming.get()
        include_num = ("001" in naming_template)

        # Handle optional dedicated playlist subfolder
        if self.chk_subfolder.get():
            now_str = datetime.now().strftime("%d.%m.%Y")
            sub_name = simpledialog.askstring(
                "Подпапка для плейлиста",
                "Введите название отдельной папки для этого плейлиста:",
                initialvalue=f"Плейлист {now_str}",
                parent=self
            )
            if not sub_name:
                return  # Cancelled by user
            clean_sub = sanitize_filename(sub_name.strip(), max_length=60)
            dest_folder = os.path.join(dest_folder, clean_sub)
            os.makedirs(dest_folder, exist_ok=True)

        self.last_dest_folder = dest_folder

        self._is_downloading = True
        self._cancel_download_flag = False

        self._set_ui_busy(True)
        self.btn_stop_download.configure(state="normal")

        total = len(self.tracks)
        self.progress_bar.set(0.0)
        self.lbl_progress_percent.configure(text="0%")
        self.lbl_status.configure(
            text=f"Подготовка к скачиванию {total} треков ({audio_format.upper()})...",
            text_color=COLOR_TEXT_PRIMARY
        )
        self.lbl_stat_status.configure(text="• Скачивание...", text_color=COLOR_WARNING)

        # Worker thread for downloads
        def download_worker():
            def track_status_cb(track_num: int, status_msg: str):
                self.after(0, self._update_row_status, track_num, status_msg)

            def progress_cb(completed: int, total_items: int, item_res: Dict[str, str]):
                self.after(0, self._on_download_item_finished, completed, total_items, item_res)

            results = self.downloader.download_tracks_batch(
                tracks=self.tracks,
                output_dir=dest_folder,
                audio_format=audio_format,
                include_number=include_num,
                on_track_status=track_status_cb,
                on_progress_update=progress_cb,
                is_cancelled=lambda: self._cancel_download_flag,
                naming_template=naming_template
            )

            self.after(0, self._on_download_batch_complete, results, dest_folder)

        self._download_thread = threading.Thread(target=download_worker, daemon=True)
        self._download_thread.start()

    def _update_row_status(self, track_num: int, status_msg: str):
        """Updates live status column and tag for a specific row in Treeview."""
        iid = str(track_num - 1)
        if self.tree.exists(iid):
            current_vals = list(self.tree.item(iid, "values"))
            if len(current_vals) >= 4:
                current_vals[3] = status_msg
                self.tree.item(iid, values=current_vals)

                # Assign tag based on status
                if "Готово" in status_msg:
                    self.tree.item(iid, tags=("done",))
                elif "Пропущен" in status_msg:
                    self.tree.item(iid, tags=("skipped",))
                elif "Ошибка" in status_msg:
                    self.tree.item(iid, tags=("error",))
                else:
                    self.tree.item(iid, tags=("active",))

    def _on_download_item_finished(self, completed: int, total: int, item_res: Dict[str, str]):
        """Updates progress bar and text as tracks complete."""
        ratio = completed / total if total > 0 else 1.0
        percent = int(ratio * 100)

        self.progress_bar.set(ratio)
        self.lbl_progress_percent.configure(text=f"{percent}%")
        status = item_res.get("status", "")
        fn = item_res.get("filename", "")
        display_fn = (fn[:55] + "...") if len(fn) > 58 else fn
        self.lbl_status.configure(
            text=f"Скачивание: {completed} из {total} ({percent}%)... [{status}] {display_fn}"
        )

    def _on_download_batch_complete(self, results: List[Dict[str, str]], dest_folder: str):
        """Called when download queue finishes."""
        self._is_downloading = False
        self._set_ui_busy(False)
        self.btn_stop_download.configure(state="disabled")

        success_count = sum(1 for r in results if r and r.get("status") == "OK")
        skipped_count = sum(1 for r in results if r and r.get("status") == "SKIPPED")
        error_count = sum(1 for r in results if r and r.get("status") == "ERROR")
        cancelled_count = sum(1 for r in results if r and r.get("status") == "CANCELLED")

        self.progress_bar.set(1.0)
        self.lbl_progress_percent.configure(text="100%")
        self.lbl_stat_status.configure(text="• Готово", text_color=COLOR_GREEN)

        summary_msg = (
            f"Скачивание завершено!\n\n"
            f"✓ Скачано новых: {success_count}\n"
            f"⏭ Пропущено (уже были): {skipped_count}\n"
        )
        if error_count > 0:
            summary_msg += f"✗ Ошибок: {error_count}\n"
        if cancelled_count > 0:
            summary_msg += f"⏹ Отменено: {cancelled_count}\n"

        summary_msg += f"\nПапка:\n{dest_folder}\n\nОткрыть папку с треками?"

        self.lbl_status.configure(
            text=f"Скачивание завершено: {success_count} скачано, {skipped_count} пропущено.",
            text_color=COLOR_GREEN
        )
        self._update_debug_log_badge()

        open_folder = messagebox.askyesno("Скачивание завершено", summary_msg)
        if open_folder:
            try:
                os.startfile(dest_folder)
            except Exception:
                webbrowser.open(dest_folder)

    def _update_debug_log_badge(self):
        """Updates the error count and visual highlight on the debug log button."""
        count = SessionDebugLogger.get_instance().error_count()
        if count > 0:
            self.btn_debug_log.configure(
                text=f"⚠️ Журнал ошибок ({count})",
                text_color=COLOR_WARNING,
                border_color=COLOR_WARNING
            )
        else:
            self.btn_debug_log.configure(
                text="📄 Журнал ошибок (0)",
                text_color=COLOR_TEXT_SECONDARY,
                border_color=COLOR_BORDER
            )

    def _open_debug_log(self):
        """Opens in-memory error log dialog."""
        ErrorLogDialog(self, on_clear_callback=self._update_debug_log_badge)

    def _retry_selected_download(self):
        """Retries downloading the selected track individually."""
        selected = self.tree.selection()
        if not selected:
            messagebox.showinfo("Выберите трек", "Выберите трек из таблицы для повторного скачивания.")
            return

        idx = int(selected[0])
        if not (0 <= idx < len(self.tracks)):
            return

        dest_folder = self.last_dest_folder
        if not dest_folder or not os.path.exists(dest_folder):
            dest_folder = filedialog.askdirectory(title="Выберите папку для сохранения трека")
            if not dest_folder:
                return
            self.last_dest_folder = dest_folder

        track = self.tracks[idx]
        num = idx + 1
        fmt_raw = self.format_selector.get()
        audio_format = "flac" if "FLAC" in fmt_raw.upper() else "mp3"
        naming_template = self.opt_naming.get()
        include_num = ("001" in naming_template)

        self._update_row_status(num, "Повтор скачивания...")

        def retry_worker():
            def track_status_cb(track_number: int, status_msg: str):
                self.after(0, self._update_row_status, track_number, status_msg)

            res = self.downloader.download_single_track(
                track_info=track,
                track_number=num,
                output_dir=dest_folder,
                audio_format=audio_format,
                include_number=include_num,
                total_tracks=len(self.tracks),
                status_callback=track_status_cb,
                naming_template=naming_template
            )

            def on_done():
                self._update_debug_log_badge()
                status = res.get("status")
                if status == "OK":
                    self._show_toast(f"Трек #{num} успешно скачан!")
                elif status == "SKIPPED":
                    self._show_toast(f"Трек #{num} уже существует.")
                else:
                    self._show_toast(f"Ошибка #{num}: {res.get('error', 'Сбой')}")

            self.after(0, on_done)

        threading.Thread(target=retry_worker, daemon=True).start()

    def _on_stop_download_clicked(self):
        """Cancels download operation."""
        self._cancel_download_flag = True
        self.lbl_status.configure(text="Остановка скачивания...", text_color=COLOR_DANGER_TEXT)
        self.btn_stop_download.configure(state="disabled")

    def _set_ui_busy(self, is_busy: bool):
        """Toggles interactive state of buttons during background tasks."""
        state = "disabled" if is_busy else "normal"
        self.btn_paste.configure(state=state)
        self.btn_manual.configure(state=state)
        self.btn_download.configure(state=state)
        self.btn_save_csv.configure(state=state)
        self.btn_save_txt.configure(state=state)
        self.btn_copy_all.configure(state=state)

    # ------------------ Tree Interaction ------------------

    def _on_tree_double_click(self, event):
        """Double clicking a row copies Artist - Title to clipboard."""
        item_id = self.tree.identify_row(event.y)
        if not item_id:
            return
        idx = int(item_id)
        if 0 <= idx < len(self.tracks):
            track = self.tracks[idx]
            text = f"{track.get('artist', '')} - {track.get('title', '')}"
            self.clipboard_clear()
            self.clipboard_append(text)
            self._show_toast(f"Скопировано: {text}")

    def _on_tree_right_click(self, event):
        """Shows context menu on right click."""
        item_id = self.tree.identify_row(event.y)
        if item_id:
            if item_id not in self.tree.selection():
                self.tree.selection_set(item_id)
            self.context_menu.post(event.x_root, event.y_root)

    def _copy_selected_track(self):
        """Copies selected tracks to clipboard as text."""
        selected = self.tree.selection()
        if not selected:
            return
        lines = []
        for iid in selected:
            idx = int(iid)
            if 0 <= idx < len(self.tracks):
                t = self.tracks[idx]
                lines.append(f"{t.get('artist', '')} - {t.get('title', '')}")
        if lines:
            text = "\n".join(lines)
            self.clipboard_clear()
            self.clipboard_append(text)
            self._show_toast(f"Скопировано треков: {len(lines)}")

    def _copy_selected_url(self):
        """Copies Spotify URL of selected track."""
        selected = self.tree.selection()
        if not selected:
            return
        idx = int(selected[0])
        if 0 <= idx < len(self.tracks):
            url = self.tracks[idx].get("url", "")
            self.clipboard_clear()
            self.clipboard_append(url)
            self._show_toast("Ссылка скопирована")

    def _open_selected_in_browser(self):
        """Opens track in web browser."""
        selected = self.tree.selection()
        if not selected:
            return
        idx = int(selected[0])
        if 0 <= idx < len(self.tracks):
            url = self.tracks[idx].get("url", "")
            if url:
                webbrowser.open(url)

    def _delete_selected_rows(self):
        """Deletes selected tracks from list."""
        selected = sorted([int(iid) for iid in self.tree.selection()], reverse=True)
        if not selected:
            return
        for idx in selected:
            if 0 <= idx < len(self.tracks):
                self.tracks.pop(idx)
        self._populate_table(self.tracks)
        self.lbl_stat_count.configure(text=f"Треков: {len(self.tracks)}")

    def _show_toast(self, message: str):
        """Briefly shows toast status message."""
        prev_text = self.lbl_status.cget("text")
        self.lbl_status.configure(text=f"✓ {message}", text_color=COLOR_GREEN)
        self.after(3000, lambda: self.lbl_status.configure(text=prev_text, text_color=COLOR_TEXT_SECONDARY))

    # ------------------ Export Handlers ------------------

    def _on_save_csv_clicked(self):
        """Saves tracks to CSV with standard Windows file dialog."""
        if not self.tracks:
            messagebox.showinfo("Список пуст", "Сначала вставьте треки из Spotify.")
            return

        filepath = filedialog.asksaveasfilename(
            title="Сохранить треки как CSV",
            defaultextension=".csv",
            filetypes=[("CSV Таблица (*.csv)", "*.csv"), ("Все файлы (*.*)", "*.*")],
            initialfile="spotify_tracks.csv"
        )
        if not filepath:
            return

        try:
            count = export_to_csv(filepath, self.tracks)
            messagebox.showinfo(
                "Экспорт завершён",
                f"Успешно экспортировано {count} треков в:\n{filepath}\n\n"
                f"Файл сохранён в UTF-8-BOM с разделителем «;» и откроется в Excel без проблем."
            )
        except Exception as e:
            messagebox.showerror("Ошибка экспорта", f"Не удалось сохранить CSV файл:\n{e}")

    def _on_save_txt_clicked(self):
        """Saves tracks to TXT with standard Windows file dialog."""
        if not self.tracks:
            messagebox.showinfo("Список пуст", "Сначала вставьте треки из Spotify.")
            return

        filepath = filedialog.asksaveasfilename(
            title="Сохранить треки как TXT",
            defaultextension=".txt",
            filetypes=[("Текстовый документ (*.txt)", "*.txt"), ("Все файлы (*.*)", "*.*")],
            initialfile="spotify_tracks.txt"
        )
        if not filepath:
            return

        try:
            count = export_to_txt(filepath, self.tracks, include_numbering=True)
            messagebox.showinfo(
                "Экспорт завершён",
                f"Успешно экспортировано {count} треков в:\n{filepath}"
            )
        except Exception as e:
            messagebox.showerror("Ошибка экспорта", f"Не удалось сохранить TXT файл:\n{e}")

    def _on_copy_all_clicked(self):
        """Copies all tracks in Artist - Title format to clipboard."""
        if not self.tracks:
            messagebox.showinfo("Список пуст", "Сначала вставьте треки из Spotify.")
            return

        formatted_text = format_tracks_as_text(self.tracks, include_numbering=False)
        self.clipboard_clear()
        self.clipboard_append(formatted_text)
        self._show_toast(f"Все {len(self.tracks)} треков скопированы в буфер обмена!")

    def _on_close(self):
        """Handles app exit cleanly."""
        self._cancel_flag = True
        self._cancel_download_flag = True
        self.destroy()


def run_app():
    ctk.set_appearance_mode("dark")
    ctk.set_default_color_theme("green")
    app = SpotiParsApp()
    app.mainloop()


if __name__ == "__main__":
    run_app()
