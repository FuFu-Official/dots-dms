"""Sliding tabs for Kitty 0.50; colors come from the live DMS/Matugen palette.

Adapted from https://github.com/patricorgi/kitty-sliding-tabs
(upstream dd9a95fd49576bc8296c55fb7a7814744a1a3e11).
The ten spare cells at the right pass geometry and colors to the shader.
"""

import time
from importlib import import_module
from typing import NamedTuple

# Kitty supplies these modules inside its embedded Python interpreter.
fast = import_module("kitty.fast_data_types")
tab_bar = import_module("kitty.tab_bar")
TabBar = tab_bar.TabBar
as_rgb = tab_bar.as_rgb
draw_tab_with_separator = tab_bar.draw_tab_with_separator

SLIDE_SECONDS = 0.180
RECORD_CELLS = 10


def draw_tab(
    draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
):
    return draw_tab_with_separator(
        draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data
    )


draw_tab.__dict__["_sliding_tabs"] = True

# Unwrap our patches on config reload instead of stacking wrappers.
native_layout = getattr(TabBar.layout, "_sliding_native", TabBar.layout)
native_update = getattr(
    TabBar.update_horizontal, "_sliding_native", TabBar.update_horizontal
)


def enabled(bar):
    return (
        getattr(bar.draw_func, "_sliding_tabs", False)
        and bar.draw_data.tab_bar_edge in ("top", "bottom")
        and "active-tab-slide-lite" in fast.get_options().custom_shaders
    )


def layout(self):
    native_layout(self)
    if not enabled(self) or not self.laid_out_once or self.margin_width:
        return
    # Put leftover fractional-cell pixels on the left. The shader can then
    # find the final cell at viewport_width - 0.5, independent of DPI/font.
    geometry = self.window_geometry
    viewport_width = self._last_viewport[2]
    offset = viewport_width - geometry.right
    if offset:
        geometry = geometry._replace(left=geometry.left + offset, right=viewport_width)
        self.window_geometry = geometry
        self.update_blank_rects(*self._last_viewport)
        fast.set_tab_bar_render_data(self.os_window_id, self.screen, *geometry[:4])


class TabSlide(NamedTuple):
    layout: tuple
    tab_id: int
    source: tuple
    target: tuple
    started: float

    def bounds(self, now):
        remaining = 1 - min(1.0, max(0.0, (now - self.started) / SLIDE_SECONDS))
        return tuple(
            round(end + (start - end) * remaining**3)
            for start, end in zip(self.source, self.target, strict=True)
        )


def marker_color(value, signature):
    packed = value | (signature << 13)
    # Spaced sRGB values survive the linear-color framebuffer roundtrip.
    channels = [96 + 5 * ((packed >> shift) & 31) for shift in (10, 5, 0)]
    return as_rgb((channels[0] << 16) | (channels[1] << 8) | channels[2])


def update_horizontal(self, data):
    changed = native_update(self, data)
    if not enabled(self):
        return changed

    active = next((tab for tab in data if tab.is_active), None)
    if active is None:
        self._tab_slide = None
        return changed
    extent = next(
        (item.x for item in self.tab_extents if item.tab_id == active.tab_id), None
    )
    screen = self.screen
    g = self.window_geometry
    central, _, width, height, cell_width, cell_height = fast.viewport_for_window(
        self.os_window_id
    )
    slot = screen.columns - RECORD_CELLS
    touches_content = (
        g.bottom == central.top
        if self.draw_data.tab_bar_edge == "top"
        else g.top == central.bottom
    )
    # Do not overwrite labels, overflow indicators or custom colored tabs.
    # A full row falls back to Kitty's ordinary rectangular highlight.
    if (
        extent is None
        or slot <= max(item.x.end for item in self.tab_extents)
        or g.right != width
        or not touches_content
        or not (1 <= cell_width <= 512 and 1 <= cell_height <= 1024)
        or self.draw_data.inactive_bg != self.draw_data.default_bg
        or self.margin_width
        or any(
            getattr(tab, name) is not None
            for tab in data
            for name in ("active_fg", "active_bg", "inactive_fg", "inactive_bg")
        )
    ):
        self._tab_slide = None
        return changed
    line = screen.line(0)
    if any(line[x] not in (" ", "\x00") for x in range(slot, screen.columns)):
        self._tab_slide = None
        return changed

    target = (g.left + extent.start * cell_width, g.left + extent.end * cell_width)
    layout_key = (
        width,
        height,
        g.top,
        cell_width,
        cell_height,
        tuple((item.tab_id, item.x) for item in self.tab_extents),
    )
    now = time.monotonic()
    old = getattr(self, "_tab_slide", None)
    if old is None or old.layout != layout_key:
        slide = TabSlide(layout_key, active.tab_id, target, target, now)
    elif old.tab_id != active.tab_id:
        slide = TabSlide(layout_key, active.tab_id, old.bounds(now), target, now)
    else:
        slide = old._replace(target=target)
    animating = slide.source != slide.target and now - slide.started < SLIDE_SECONDS
    if not animating:
        slide = slide._replace(source=target)
    self._tab_slide = slide

    values = (cell_width, cell_height, *slide.bounds(now), *target)
    if any(value < 0 or value >= 8192 for value in values):
        self._tab_slide = None
        return changed
    # Record is ordered from right to left; the shader decodes the cell width
    # first, then uses it to locate the remaining nine cells.
    colors = [
        marker_color(value, signature)
        for value, signature in zip(values, (1, 2, 1, 2, 3, 2), strict=True)
    ]
    colors.extend(
        as_rgb(int(color))
        for color in (
            self.draw_data.active_bg,
            self.draw_data.active_fg,
            self.draw_data.inactive_fg,
            self.draw_data.default_bg,
        )
    )
    cursor = screen.cursor
    previous_x, previous_bg = cursor.x, cursor.bg
    for offset, color in enumerate(colors):
        cursor.x = screen.columns - 1 - offset
        cursor.bg = color
        screen.draw(" ")
    cursor.x, cursor.bg = previous_x, previous_bg

    if animating and not getattr(self, "_tab_slide_timer", None):

        def next_frame(_timer_id):
            self._tab_slide_timer = None
            manager = fast.get_boss().os_window_map.get(self.os_window_id)
            if (
                manager is not None
                and not manager.tab_bar_hidden
                and manager.tab_bar_should_be_visible
            ):
                manager.update_tab_bar_data()
                fast.mark_tab_bar_dirty(self.os_window_id, True)

        self._tab_slide_timer = fast.add_timer(next_frame, 0.010, False)
    return changed


layout.__dict__["_sliding_native"] = native_layout
update_horizontal.__dict__["_sliding_native"] = native_update
TabBar.layout = layout
TabBar.update_horizontal = update_horizontal
