'use strict';
// Usage: node tray-menu-linux.js <app dir>
// Electron's popUpContextMenu() only works on macOS and Windows. On Linux, trays (StatusNotifierItem
// or XEmbed) can only show a menu the app sets beforehand with setContextMenu().
const fs = require('fs');
const path = require('path');

const REFRESH_MS = 1000; // the menu shows the session's elapsed time

// Matches the non-macOS tray code by shape: minified names (`_s`, `n` in 1.4.2) change each release.
// (\w+) captures the tray and the menu builder; no match means nothing is patched.
const PATTERN = /(\w+)\.on\("right-click",\(\)=>\{\1\.popUpContextMenu\((\w+)\(\)\)\}\),\1\.on\("click",\(\)=>\{\1\.popUpContextMenu\(\2\(\)\)\}\)/;

// Copied into the app as source: it may only use its arguments and globals.
function keepTrayMenuSet(tray, buildMenu, refreshMs) {
	let shown;
	const describe = menu => JSON.stringify(menu.items.map(item =>
		[item.label, item.enabled, item.checked, item.visible, item.submenu && describe(item.submenu)]));
	const update = () => {
		if (tray.isDestroyed()) return;
		const menu = buildMenu();
		const description = describe(menu);
		// Only on change: replacing the menu redraws it if it's open.
		if (description !== shown) {
			shown = description;
			tray.setContextMenu(menu);
		}
	};
	update();
	setInterval(update, refreshMs);
}

const dir = path.join(process.argv[2], '.vite/build');
for (const name of fs.readdirSync(dir).filter(f => f.endsWith('.js'))) {
	const file = path.join(dir, name);
	const code = fs.readFileSync(file, 'utf8');
	const match = PATTERN.exec(code);
	if (!match) continue;
	const [original, tray, menu] = match;
	const linux = `(${keepTrayMenuSet})(${tray},${menu},${REFRESH_MS})`;
	fs.writeFileSync(file, code.replace(original, () => `process.platform==="linux"?${linux}:(${original})`));
	console.log(`Tray menu patched in ${name}`);
	process.exit(0);
}
console.log('Tray menu code not found, tray left as is');
