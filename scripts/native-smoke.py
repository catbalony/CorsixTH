#!/usr/bin/env python3
"""Real SDL/Xvfb CorsixTH sprite-viewer integration smoke test.

Only works with separately provided original Theme Hospital resources and an
official CorsixTH AppImage. Keeps all third-party inputs and screenshots OUT of
Git. Uses built-in Shift+D debug script; does not edit app.lua or game assets.
"""
from __future__ import annotations

import argparse
import ctypes
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def require(cond: bool, message: str) -> None:
    if not cond:
        raise RuntimeError(message)


def prepare(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    here = Path(__file__).resolve().parent.parent
    root = args.workdir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    extracted = root / 'appimage' / 'squashfs-root'
    if not extracted.exists():
        require(args.appimage.is_file(), f'AppImage not found: {args.appimage}')
        (root / 'appimage').mkdir(exist_ok=True)
        result = subprocess.run([str(args.appimage.resolve()), '--appimage-extract'],
                                cwd=root / 'appimage', capture_output=True, text=True)
        require(result.returncode == 0, f'AppImage extraction failed: {result.stderr}')
    game = root / 'game'
    game.mkdir(exist_ok=True)
    for folder in ('DATA', 'DATAM', 'QDATA', 'QDATAM'):
        source = args.game_data.resolve() / folder
        require(source.is_dir(), f'Original game folder missing: {source}')
        dest = game / folder
        if dest.is_symlink() or dest.exists():
            require(dest.is_symlink() and dest.resolve() == source, f'refusing to overwrite {dest}')
        else:
            dest.symlink_to(source, target_is_directory=True)
    level = game / 'Levels' / 'Level.L1'
    level.parent.mkdir(exist_ok=True)
    require(args.level.is_file(), f'level file not found: {args.level}')
    shutil.copyfile(args.level.resolve(), level)

    lua_root = root / 'Lua'
    if not lua_root.exists():
        shutil.copytree(extracted / 'usr/share/corsix-th/Lua', lua_root)
    for module in ('sprite_viewer.lua', 'sprite_viewer_recipe.lua',
                   'sprite_viewer_browser.lua', 'sprite_viewer_selection.lua',
                   'sprite_viewer_layout.lua'):
        shutil.copy2(here / 'CorsixTH/Lua' / module, lua_root / module)
    (lua_root / 'debug_script.lua').write_text('corsixth.require("sprite_viewer")()\n')
    # Each invocation gets a fresh output directory. Never accept stale PNGs or
    # recipes from a previous successful run as evidence of this invocation.
    screenshots = root / 'Screenshots' / f'run-{time.time_ns()}-{os.getpid()}'
    screenshots.mkdir(parents=True, exist_ok=False)
    (root / 'home').mkdir(exist_ok=True)
    config = root / 'config.txt'
    config.write_text('\n'.join([
        '-- Private native sprite-viewer smoke test; generated automatically',
        'fullscreen = false', 'width = 640', 'height = 480', 'ui_scale = 1',
        'language = [[english]]', 'debug = true',
        'play_sounds = false', 'play_music = false', 'play_announcements = false',
        f'theme_hospital_install = [[{game}]]',
        f'screenshots = [[{screenshots}]]',
        f'unicode_font = [[{extracted / "usr/share/corsix-th/CorsixTHUnicode.ttf"}]]',
        '',
    ]))
    return root, extracted, screenshots


class XInputs:
    def __init__(self) -> None:
        x11 = ctypes.CDLL('libX11.so.6')
        xtest = ctypes.CDLL('libXtst.so.6')
        x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
        x11.XOpenDisplay.restype = ctypes.c_void_p
        x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
        x11.XStringToKeysym.restype = ctypes.c_ulong
        x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        x11.XKeysymToKeycode.restype = ctypes.c_uint
        x11.XFlush.argtypes = [ctypes.c_void_p]
        xtest.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
        xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        self.x11, self.xtest = x11, xtest
        self.d = x11.XOpenDisplay(None)
        require(bool(self.d), f'Unable to open X display {os.environ.get("DISPLAY")}')

    def code(self, name: str) -> int:
        code = self.x11.XKeysymToKeycode(self.d, self.x11.XStringToKeysym(name.encode()))
        require(bool(code), f'Unknown X key: {name}')
        return code

    def down(self, code: int) -> None:
        self.xtest.XTestFakeKeyEvent(self.d, code, 1, 0)
        self.x11.XFlush(self.d)
        time.sleep(.07)

    def up(self, code: int) -> None:
        self.xtest.XTestFakeKeyEvent(self.d, code, 0, 0)
        self.x11.XFlush(self.d)
        time.sleep(.07)

    def key(self, name: str, modifier: str | None = None) -> None:
        mod = self.code(modifier) if modifier else None
        if mod: self.down(mod)
        key = self.code(name)
        self.down(key)
        self.up(key)
        if mod: self.up(mod)
        time.sleep(.09)

    def click(self, x: int, y: int) -> None:
        self.xtest.XTestFakeMotionEvent(self.d, -1, x, y, 0)
        self.x11.XFlush(self.d)
        time.sleep(.1)
        self.xtest.XTestFakeButtonEvent(self.d, 1, 1, 0)
        self.x11.XFlush(self.d)
        time.sleep(.08)
        self.xtest.XTestFakeButtonEvent(self.d, 1, 0, 0)
        self.x11.XFlush(self.d)
        time.sleep(.1)


def run(args: argparse.Namespace) -> None:
    root, extracted, screenshots = prepare(args)
    display_id = args.display or ':147'
    xcmd = ['Xvfb', display_id, '-screen', '0', '1024x768x24', '-nolisten', 'tcp']
    env = dict(os.environ, DISPLAY=display_id, HOME=str(root / 'home'),
               SDL_VIDEODRIVER='x11', XDG_CONFIG_HOME=str(root / 'home'))
    xlog = (root / 'xvfb.log').open('w')
    xproc = subprocess.Popen(xcmd, stdout=xlog, stderr=subprocess.STDOUT)
    gameproc = None
    logfile = root / 'corsixth.log'
    try:
        time.sleep(1)
        require(xproc.poll() is None, 'Xvfb failed to start; see xvfb.log')
        binary = extracted / 'AppRun'
        require(binary.exists(), f'extracted AppRun missing: {binary}')
        cmd = [str(binary), f'--lua-dir={root / "Lua"}', f'--config-file={root / "config.txt"}']
        with logfile.open('w') as game_log:
            gameproc = subprocess.Popen(cmd, cwd=root, env=env, stdout=game_log,
                                        stderr=subprocess.STDOUT)
            time.sleep(args.boot_delay)
            require(gameproc.poll() is None, 'CorsixTH exited before viewer; see corsixth.log')
            # XTest is the same X input path as a real keyboard/mouse, not the
            # mocked Lua event dispatcher. Main menu activates Debug Script.
            previous = os.environ.get('DISPLAY')
            os.environ['DISPLAY'] = display_id
            try:
                x = XInputs()
                x.click(480, 180)  # activate main window in centered 640x480 area
                x.key('d', 'Shift_L')
                time.sleep(.55)
                for ch in ('slash', 'p', 'a', 'n', 'e', 'l', '0', '4'):
                    x.key(ch)
                x.key('Return')
                x.key('g'); x.key('1'); x.key('Return')
                for _ in range(8): x.key('k', 'Shift_L')
                x.key('v')
                x.key('s', 'Control_L')
                x.key('x')
                time.sleep(.7)
                x.key('t'); x.key('space')
                time.sleep(.5)
                x.key('space'); x.key('q')
                time.sleep(.3)
            finally:
                if previous is None: os.environ.pop('DISPLAY', None)
                else: os.environ['DISPLAY'] = previous
            require(gameproc.poll() is None, 'CorsixTH exited while testing viewer')
    finally:
        if gameproc is not None and gameproc.poll() is None:
            gameproc.terminate()
            try: gameproc.wait(timeout=4)
            except subprocess.TimeoutExpired: gameproc.kill(); gameproc.wait()
        xproc.terminate()
        try: xproc.wait(timeout=3)
        except subprocess.TimeoutExpired: xproc.kill(); xproc.wait()
        xlog.close()

    log_text = logfile.read_text(errors='replace')
    require('Executing Debug Script' in log_text, 'debug viewer not opened; check log')
    errors = ('Lua Error', 'Error in', 'stack traceback', 'attempt to ', 'error loading module')
    require(not any(word.lower() in log_text.lower() for word in errors),
            'Lua/native error occurred; see corsixth.log')
    recipe = screenshots / 'SpriteViewer_Data_PANEL04V.svr'
    require(recipe.is_file(), 'native viewer did not write the requested recipe')
    lines = recipe.read_text().strip().splitlines()
    require(lines[0] == 'SVR1\tData\tPANEL04V\tcomplex\tstrip', 'incorrect recipe metadata')
    require([int(line.split('\t')[0]) for line in lines[1:]] == list(range(1, 10)),
            f'native shift-selection did not select ECG frames 1..9: {lines}')
    captured = list(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
    require(captured, 'native SDL screenshot missing')
    for png in captured:
        require(png.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', f'not a valid PNG: {png}')
    print(f'PASS: real CorsixTH SDL launch, search, range select, 9-frame recipe, screenshot, animation & clean exit')
    print(f'  log: {logfile}\n  recipe: {recipe}\n  native PNGs: {len(captured)}')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--appimage', type=Path, required=True, help='original CorsixTH 0.70.1 x86_64 AppImage')
    p.add_argument('--game-data', type=Path, required=True, help='directory containing DATA, QDATA etc (unpacked archive)')
    p.add_argument('--level', type=Path, required=True, help='tester-provided LEVEL.L1')
    p.add_argument('--workdir', type=Path, default=Path('.local-native'), help='gitignored temp native test root')
    p.add_argument('--display', default=None, help='Xvfb display, default :147')
    p.add_argument('--boot-delay', type=float, default=3.5)
    args = p.parse_args()
    try: run(args)
    except Exception as ex:
        print(f'FAIL: {ex}', file=sys.stderr)
        raise SystemExit(1) from ex

if __name__ == '__main__': main()
