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
import re
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
    require(args.initial_width >= 640 and args.initial_height >= 480,
            'CorsixTH 0.70.1 requires at least 640x480; smaller window sizes are unsupported')
    # PANEL04V frames #1..#9 form a 792px strip. At 800px no overview is
    # needed, so there is nothing to hit-test until we resize to 640px.
    if args.assembly_navigation_check and not args.resize_check:
        require(args.initial_width < 792,
                'PANEL04V overview is hidden at >=792px; use --resize-check '
                'to test overview clicks after returning to a 640px viewport')
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
                   'sprite_viewer_layout.lua', 'sprite_viewer_assembly.lua',
                   'sprite_viewer_history.lua'):
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
        'fullscreen = false', f'width = {args.initial_width}', f'height = {args.initial_height}', 'ui_scale = 1',
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

    def resize_window(self, width: int, height: int) -> None:
        # Xvfb has no window manager, so wmctrl cannot be used. Query the
        # actual CorsixTH X11 window and resize it via Xlib (not a Lua mock).
        listing = subprocess.run(['xwininfo', '-root', '-tree'],
                                 capture_output=True, text=True, check=True).stdout
        found = re.search(r'(0x[0-9a-fA-F]+) "CorsixTH"', listing)
        require(found is not None, 'CorsixTH X11 window not found')
        xid = int(found.group(1), 16)
        self.x11.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong,
                                           ctypes.c_uint, ctypes.c_uint]
        self.x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
        self.x11.XResizeWindow(self.d, xid, width, height)
        self.x11.XSync(self.d, 0)
        time.sleep(.6)

    def window_origin(self) -> tuple[int, int]:
        # SDL's 640x480 window does not necessarily start at X11 origin (0,0).
        # Resolve screen coordinates before testing mouse-driven overview input.
        listing = subprocess.run(['xwininfo', '-root', '-tree'],
                                 capture_output=True, text=True, check=True).stdout
        found = re.search(r'(0x[0-9a-fA-F]+) "CorsixTH"', listing)
        require(found is not None, 'Cannot locate the CorsixTH X11 window')
        info = subprocess.run(['xwininfo', '-id', found.group(1)],
                              capture_output=True, text=True, check=True).stdout
        left = re.search(r'Absolute upper-left X:\s*(-?\d+)', info)
        top = re.search(r'Absolute upper-left Y:\s*(-?\d+)', info)
        require(left is not None and top is not None,
                'Cannot resolve CorsixTH X11 window origin')
        return int(left.group(1)), int(top.group(1))

    def scroll(self, direction: int) -> None:
        # XTest buttons 4/5 are actual X11 wheel events received by SDL3.
        require(direction in (-1, 1), 'Wheel direction must be -1 or 1')
        button = 4 if direction > 0 else 5
        self.xtest.XTestFakeButtonEvent(self.d, button, 1, 0)
        self.x11.XFlush(self.d)
        time.sleep(.08)
        self.xtest.XTestFakeButtonEvent(self.d, button, 0, 0)
        self.x11.XFlush(self.d)
        time.sleep(.15)

    def window_size(self) -> tuple[int, int]:
        listing = subprocess.run(['xwininfo', '-root', '-tree'],
                                 capture_output=True, text=True, check=True).stdout
        found = re.search(r'(0x[0-9a-fA-F]+) "CorsixTH"', listing)
        require(found is not None, 'CorsixTH window not found in X11 tree')
        info = subprocess.run(['xwininfo', '-id', found.group(1)],
                              capture_output=True, text=True, check=True).stdout
        w = re.search(r'Width:\s*(\d+)', info)
        h = re.search(r'Height:\s*(\d+)', info)
        require(w is not None and h is not None, 'Cannot determine CorsixTH window dimensions')
        return int(w.group(1)), int(h.group(1))

    def click_window(self, x: int, y: int) -> None:
        width, height = self.window_size()
        require(0 <= x < width and 0 <= y < height,
                f'Click outside CorsixTH window {width}x{height}: ({x}, {y})')
        root_x, root_y = self.window_origin()
        self.click(root_x + x, root_y + y)

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
                actual_w, actual_h = x.window_size()
                require(actual_w == args.initial_width and actual_h == args.initial_height,
                        f'Native window size differs from requested {args.initial_width}x{args.initial_height}: '
                        f'{actual_w}x{actual_h}')
                x.click_window(actual_w // 2, min(150, actual_h // 2))
                x.key('d', 'Shift_L')
                time.sleep(.55)
                for ch in ('slash', 'p', 'a', 'n', 'e', 'l', '0', '4'):
                    x.key(ch)
                x.key('Return')
                x.key('g'); x.key('1'); x.key('Return')
                for _ in range(8): x.key('k', 'Shift_L')
                if args.resize_check:
                    # CorsixTH 0.70.1 enforces 640x480 minimum in app.lua.
                    # Exercising a forced 320x200 bypasses that contract and
                    # produces cropped drawing / mismatched mouse coordinates.
                    # Resize to a genuinely supported larger window instead.
                    x.resize_window(800, 600)
                    require(x.window_size() == (800, 600), 'X11 resize did not take effect')
                    x.key('x')
                    x.resize_window(640, 480)
                    require(x.window_size() == (640, 480), 'Could not restore window size')
                x.key('v')
                if args.assembly_navigation_check:
                    # Nine original ECG panels exceed the baseline viewport.
                    # Verify keyboard page transitions and hit-test the real
                    # proportional overview at the bottom of the SDL window.
                    x.key('x')  # focus initially on #9
                    x.key('Home'); x.key('x')
                    x.key('End'); x.key('x')
                    x.key('Page_Up'); x.key('x')
                    x.key('Page_Down'); x.key('x')
                    # Verify *which* component was selected by looking for
                    # the warm focus marker in the real PNG, not merely by
                    # counting how many screenshots were generated.
                    def capture_overview_click(relative_x: int, height: int) -> Path:
                        before = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
                        x.click_window(relative_x, height - 42)
                        x.key('x')
                        time.sleep(.2)
                        after = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
                        generated = after - before
                        require(len(generated) == 1,
                                f'Expected one fresh SDL screenshot, got {len(generated)}')
                        return generated.pop()
                    baseline_width = 640 if args.resize_check else args.initial_width
                    baseline_height = 480 if args.resize_check else args.initial_height
                    first_overview = capture_overview_click(12, baseline_height)
                    before = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
                    x.scroll(-1)  # wheel down = next component, matching K
                    x.key('x')
                    time.sleep(.2)
                    new_wheel = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png')) - before
                    require(len(new_wheel) == 1, 'Wheel movement capture missing')
                    next_overview = new_wheel.pop()
                    last_overview = capture_overview_click(baseline_width - 12, baseline_height)
                if args.resize_check:
                    x.resize_window(800, 600)
                    require(x.window_size() == (800, 600), 'Assembly resize failed')
                    x.key('x')
                    if args.assembly_navigation_check:
                        first_overview_big = capture_overview_click(12, 600)
                        last_overview_big = capture_overview_click(788, 600)
                    x.resize_window(640, 480)
                    require(x.window_size() == (640, 480), 'Assembly restore failed')
                if args.assembly_pick_check:
                    # Native composited-image hit testing, separate from chips
                    # and overview. Focus changes are asserted from real SDL
                    # pixel captures, not inferred from successful mouse calls.
                    require(x.window_size() == (640, 480),
                            'native preview pixel assertions require 640x480')
                    def capture_preview(action) -> Path:
                        before = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
                        action()
                        x.key('x')
                        time.sleep(.2)
                        created = set(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png')) - before
                        require(len(created) == 1, 'Expected one new native composite screenshot')
                        return created.pop()
                    x.key('End')
                    picked_strip_8 = capture_preview(lambda: x.click_window(480, 215))
                    picked_strip_9 = capture_preview(lambda: x.click_window(575, 215))
                    x.key('m')   # overlapping zero-offset layers
                    picked_layer_9 = capture_preview(lambda: x.click_window(300, 215))
                    shift = x.code('Shift_L')
                    def shift_pick():
                        x.down(shift)
                        try: x.click_window(300, 215)
                        finally: x.up(shift)
                    picked_layer_8 = capture_preview(shift_pick)
                    picked_layer_7 = capture_preview(shift_pick)
                    x.key('m')
                    x.key('End')
                def assembly_button(action: str, mode: str) -> None:
                    # Layout.assembly_controls is based on the visible canvas
                    # width, not constant coordinates from an earlier release.
                    strip = ['move-left', 'move-right', 'copy-minus', 'copy-plus',
                             'reset', 'undo', 'redo']
                    layers = ['move-left', 'move-right', 'dx-minus', 'dx-plus',
                              'dy-minus', 'dy-plus', 'reset', 'undo', 'redo']
                    actions = strip if mode == 'strip' else layers
                    index = actions.index(action)
                    width, height = x.window_size()
                    gap = 5
                    bw = max(1, min(92, (max(1, width - 16) - gap * (len(actions) - 1)) // len(actions)))
                    total = bw * len(actions) + gap * (len(actions) - 1)
                    cx = (width - total) // 2 + index * (bw + gap) + bw // 2
                    x.click_window(cx, height - 93)
                if args.assembly_edit_check:
                    # 640x480 toolbar positions, calculated by Layout.assembly_controls.
                    # The edited values are verified from the *real* saved SVR1
                    # file, not merely by looking for button labels in a PNG.
                    require(x.window_size() == (640, 480),
                            'edit controls require the baseline 640x480 viewport')
                    assembly_button('move-left', 'strip')  # focused #9: Order <
                    assembly_button('copy-plus', 'strip')  # Copies +, from 1 to 2
                    x.key('x')                 # strip editor screenshot
                    x.key('m')                 # enter layers
                    shift = x.code('Shift_L')
                    x.down(shift)
                    try: assembly_button('dx-plus', 'layers')  # X +, Shift = 8 px
                    finally: x.up(shift)
                    assembly_button('dy-plus', 'layers') # Y +, 1 px
                    x.key('x')                # layer editor screenshot
                    x.key('m')                # strip, preserve hidden offsets
                    if args.assembly_history_check:
                        # Undo the four real mouse actions: Y+, Shift X+,
                        # Copies+ and Order<, then SAVE that base state.
                        for _ in range(4): x.key('z', 'Control_L')
                        x.key('s', 'Control_L')
                        x.key('x')
                        # Redo using both keyboard conventions and actual
                        # clickable toolbar buttons; save once more. The
                        # backup must contain the complete *undone* recipe.
                        for _ in range(2): x.key('y', 'Control_L')
                        shift = x.code('Shift_L')
                        x.down(shift)
                        try:
                            for _ in range(2): x.key('z', 'Control_L')
                        finally:
                            x.up(shift)
                        assembly_button('undo', 'strip')
                        # Save the intermediate mouse-undo state. Overwrite
                        # creates .bak1 (fully undone base state).
                        x.key('s', 'Control_L')  # request overwrite
                        x.key('s', 'Control_L')  # commit intermediate state
                        assembly_button('redo', 'strip')
                        # Overwrite again: .bak2 must contain the state with
                        # dy=0, demonstrating native clicked Undo/Redo.
                        x.key('s', 'Control_L')
                        x.key('s', 'Control_L')
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
    if args.assembly_edit_check:
        expected_order = [1,2,3,4,5,6,7,9,8]
        require([int(line.split('\t')[0]) for line in lines[1:]] == expected_order,
                f'actual mouse reorder did not update recipe: {lines}')
        # Saved offsets survive switching out of layers; repetitions survive
        # switching out of strip. Neither edit affects the original art.
        edited = [line.split('\t') for line in lines[1:]][7]
        require(edited == ['9','8','1','2'],
                f'actual SDL edit controls saved wrong values: {edited}')
    else:
        require([int(line.split('\t')[0]) for line in lines[1:]] == list(range(1, 10)),
                f'native shift-selection did not select ECG frames 1..9: {lines}')
    if args.assembly_history_check:
        backups = sorted(screenshots.glob('SpriteViewer_Data_PANEL04V.svr.bak*'))
        require(len(backups) == 2, f'Undo/redo intermediate backups missing: {backups}')
        backup_lines = backups[0].read_text().strip().splitlines()
        require(backup_lines[0] == 'SVR1\tData\tPANEL04V\tcomplex\tstrip',
                'Undo recipe header corrupted')
        base_items = [line.split('\t') for line in backup_lines[1:]]
        require([int(fields[0]) for fields in base_items] == list(range(1,10)),
                f'Undo did not restore original checked order: {base_items}')
        require(all(fields[1:] == ['0','0','1'] for fields in base_items),
                f'Undo did not restore original offsets/copies: {base_items}')
        intermediate = backups[1].read_text().strip().splitlines()
        require([int(line.split('\t')[0]) for line in intermediate[1:]] ==
                [1,2,3,4,5,6,7,9,8],
                'Native mouse Undo unexpectedly changed the component order')
        require(intermediate[8].split('\t') == ['9','8','0','2'],
                f'Native mouse Undo did not revert Y offset: {intermediate[8]}')
    captured = list(screenshots.glob('SpriteViewer_Data_PANEL04V_*.png'))
    require(captured, 'native SDL screenshot missing')
    dimensions = set()
    for png in captured:
        data = png.read_bytes()
        require(data[:8] == b'\x89PNG\r\n\x1a\n', f'not a valid PNG: {png}')
        dimensions.add((int.from_bytes(data[16:20], 'big'),
                        int.from_bytes(data[20:24], 'big')))
    if args.resize_check:
        require((800, 600) in dimensions and (640, 480) in dimensions,
                f'Native screenshots do not reflect supported SDL resizing: {dimensions}')
    if args.assembly_navigation_check:
        try:
            from PIL import Image
        except ImportError as ex:
            raise RuntimeError('Native overview assertions require Pillow (python3-pil)') from ex

        def marker_center(png: Path) -> tuple[int, int]:
            with Image.open(png) as raw:
                im = raw.convert('RGB')
                # SDL's logical drawing size and the X11 window's physical
                # pixel size can differ slightly immediately after a resize.
                # Find the 7-pixel-high focus marker near the bottom of the
                # screenshot rather than assuming a single absolute y row.
                target = (226, 180, 100)
                pixels = im.load()
                marker_rows = []
                for y in range(max(0, im.height - 85), im.height - 10):
                    xs = [x for x in range(8, im.width - 8)
                          if pixels[x, y] == target]
                    if xs:
                        marker_rows.append(xs)
                require(marker_rows, f'No assembly-focus marker: {png}')
                marked = max(marker_rows, key=len)
                return (min(marked) + max(marked)) // 2, im.width

        def verify_clicks(left: Path, right: Path) -> None:
            left_x, width = marker_center(left)
            right_x, right_width = marker_center(right)
            require(width == right_width, 'Overview captures have different sizes')
            require(left_x < width // 4 and right_x > width * 3 // 4,
                    f'Real X11 overview clicks did not select opposite ends: '
                    f'{left_x} and {right_x} / {width}')
        verify_clicks(first_overview, last_overview)
        focus_first, image_width = marker_center(first_overview)
        focus_second, _ = marker_center(next_overview)
        focus_last, _ = marker_center(last_overview)
        require(focus_first < focus_second < focus_last,
                f'Wheel down did not navigate to the next component: '
                f'{focus_first} -> {focus_second} -> {focus_last} / {image_width}')
        if args.resize_check:
            verify_clicks(first_overview_big, last_overview_big)
    if args.assembly_pick_check:
        try:
            from PIL import Image
        except ImportError as ex:
            raise RuntimeError('Native preview focus assertions require Pillow') from ex
        highlight = (132, 199, 206)
        def inspect_focus(png: Path, chip_x: int) -> None:
            with Image.open(png) as im:
                rgb = im.convert('RGB')
                require(rgb.size == (640, 480), f'Unexpected native capture size: {png}')
                actual = rgb.getpixel((chip_x, 446))
                require(actual == highlight,
                        f'Click on preview did not focus expected component at x={chip_x}: '
                        f'got {actual} instead of {highlight} in {png.name}')
        # Stable component pages have eight chips per page at 640px.
        # Strip focus #8 / #9; overlapping layers should pick topmost #9,
        # then Shift-cycle behind to #8 and #7 in actual draw order.
        inspect_focus(picked_strip_8, 510)
        inspect_focus(picked_strip_9, 20)
        inspect_focus(picked_layer_9, 20)
        inspect_focus(picked_layer_8, 510)
        inspect_focus(picked_layer_7, 440)
    print(f'PASS: real CorsixTH SDL launch, search, range select, 9-frame recipe, screenshot, animation & clean exit')
    print(f'  log: {logfile}\n  recipe: {recipe}\n  native PNGs: {len(captured)}')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--appimage', type=Path, required=True, help='original CorsixTH 0.70.1 x86_64 AppImage')
    p.add_argument('--game-data', type=Path, required=True, help='directory containing DATA, QDATA etc (unpacked archive)')
    p.add_argument('--level', type=Path, required=True, help='tester-provided LEVEL.L1')
    p.add_argument('--workdir', type=Path, default=Path('.local-native'), help='gitignored temp native test root')
    p.add_argument('--display', default=None, help='Xvfb display, default :147')
    p.add_argument('--initial-width', type=int, default=640)
    p.add_argument('--initial-height', type=int, default=480)
    p.add_argument('--boot-delay', type=float, default=3.5)
    p.add_argument('--resize-check', action='store_true', help='verify supported real SDL X11 800x600/640x480 resize and screenshots')
    p.add_argument('--assembly-navigation-check', action='store_true',
                   help='exercise stable assembly pages and click the overview in real X11')
    p.add_argument('--assembly-edit-check', action='store_true',
                   help='edit copies, order and layer offsets using real SDL mouse events')
    p.add_argument('--assembly-history-check', action='store_true',
                   help='undo/redo native assembly edits, assert saved backup/final recipes')
    p.add_argument('--assembly-pick-check', action='store_true',
                   help='click composited sprites and Shift-cycle overlapping layers with native PNG focus checks')
    args = p.parse_args()
    if args.assembly_history_check and not args.assembly_edit_check:
        p.error('--assembly-history-check requires --assembly-edit-check')
    try: run(args)
    except Exception as ex:
        print(f'FAIL: {ex}', file=sys.stderr)
        raise SystemExit(1) from ex

if __name__ == '__main__': main()
