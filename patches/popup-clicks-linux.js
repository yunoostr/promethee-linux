'use strict';
// Electron forwards mouse moves to click-through windows on macOS and Windows only
// (https://www.electronjs.org/docs/latest/api/browser-window#winsetignoremouseeventsignore-options), and
// XWayland loses the cursor position over native Wayland windows, so Promethee's popups never get clicks back.
// Native Wayland ignores window shapes.
const {app, BrowserWindow} = require('electron');

const POLL_MS = 100;
const SETTLE_MS = 500;
const TARGETS = '.promethee-mouse-target';

const PAGE_TARGET_BOXES = `[...document.querySelectorAll(${JSON.stringify(TARGETS)})].map(e => e.getBoundingClientRect())
  .filter(r => r.width > 0 && r.height > 0).map(r => [r.left, r.top, r.right, r.bottom])`;

const contains = (a, r) => a.x <= r.x && a.y <= r.y && a.x + a.width >= r.x + r.width && a.y + a.height >= r.y + r.height;

function toRects(boxes, zoom) {
	return boxes.map(([left, top, right, bottom]) => {
		const x = Math.floor(left * zoom), y = Math.floor(top * zoom);
		return {x, y, width: Math.ceil(right * zoom) - x, height: Math.ceil(bottom * zoom) - y};
	});
}

const ozone = app.commandLine.getSwitchValue('ozone-platform');
const x11 = ozone ? ozone === 'x11' : !process.env.WAYLAND_DISPLAY;   // Electron picks Wayland when it can

if (process.platform === 'linux' && x11) {
	const setIgnoreMouseEvents = BrowserWindow.prototype.setIgnoreMouseEvents;
	const timers = new WeakMap();

	const stop = win => {
		clearInterval(timers.get(win));
		timers.delete(win);
	};

	const follow = win => {
		let applied = null, seen, seenAt;
		const update = async () => {
			let boxes;
			try {
				boxes = await win.webContents.executeJavaScript(PAGE_TARGET_BOXES);
			} catch {
				return;
			}
			if (!timers.has(win) || win.isDestroyed()) return;
			const rects = toRects(boxes, win.webContents.getZoomFactor());
			const key = JSON.stringify(rects);
			if (key !== seen) {
				seen = key;
				seenAt = Date.now();
			}
			// X11 never repaints outside a window's shape: shrinking before the page has cleared that area leaves it on screen.
			const next = applied === null || Date.now() - seenAt >= SETTLE_MS ? rects
				: applied.concat(rects.filter(r => !applied.some(a => contains(a, r))));
			if (applied !== null && JSON.stringify(next) === JSON.stringify(applied)) return;
			applied = next;
			if (next.length > 0) {
				setIgnoreMouseEvents.call(win, false);   // XWayland only takes clicks back with the new shape
				win.setShape(next);
			} else {
				win.setShape([]);
				setIgnoreMouseEvents.call(win, true);
			}
		};
		timers.set(win, setInterval(update, POLL_MS));
		win.once('closed', () => stop(win));
		update();
	};

	BrowserWindow.prototype.setIgnoreMouseEvents = function (ignore, options) {
		if (ignore && options && options.forward) {
			if (!timers.has(this)) follow(this);
			return;
		}
		if (!timers.has(this)) return setIgnoreMouseEvents.call(this, ignore, options);
		if (!ignore) return;
		stop(this);
		this.setShape([]);
		return setIgnoreMouseEvents.call(this, ignore, options);
	};
}
