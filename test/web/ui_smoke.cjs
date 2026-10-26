// End-to-end test of MSXTRACK Web in headless Chromium (Playwright).
// usage: node test/web/ui_smoke.cjs http://localhost:8765/ <download dir>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const url = process.argv[2] || 'http://localhost:8765/';
const outDir = process.argv[3] || '/tmp';
let fails = 0;
const check = (name, ok, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${extra ? ` (${extra})` : ''}`); if (!ok) fails++; };

(async () => {
  const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: 1440, height: 950 }, acceptDownloads: true });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(url);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await page.waitForFunction(() => window.msxtrack && window.msxtrack.app.song.name === 'DEMO TUNE');
  const app = (expr) => page.evaluate(expr);

  check('demo song loaded', true);
  check('pattern shows the bass', (await page.textContent('#grid')).includes('A-2'));

  // playback through the AudioWorklet
  await page.click('#btn-play-song');
  await page.waitForTimeout(1500);
  const pos = await app(() => ({ playing: window.msxtrack.app.playing, row: window.msxtrack.app.playRow }));
  check('song plays', pos.playing === 1 && pos.row > 0, `row ${pos.row}`);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(200);
  check('Esc stops', (await app(() => window.msxtrack.app.playing)) === 0);

  // note entry with the keyboard
  await page.click('#grid .prow[data-row="1"] .cell[data-ch="0"] .f[data-col="0"]');
  await page.keyboard.press('KeyQ');                 // C-5 at octave 4
  const c1 = await app(() => window.msxtrack.app.song.getCell(0, 1, 0));
  check('Q types C-5 with instrument 1', c1.note === 49 && c1.ins === 1, JSON.stringify(c1));
  check('cursor moved down one row', (await app(() => window.msxtrack.app.row)) === 2);
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('ArrowRight');           // effect column
  await page.keyboard.press('ArrowUp');
  await page.keyboard.type('442');
  const c2 = await app(() => window.msxtrack.app.song.getCell(0, 1, 0));
  check('effect 442 entered', c2.fx === 4 && c2.param === 0x42, JSON.stringify(c2));
  await page.keyboard.press('ArrowUp');
  check('hint names the effect under the cursor', (await page.textContent('#hint')).includes('Vibrato'));
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Control+z');
  check('Ctrl+Z undoes the last digit', (await app(() => window.msxtrack.app.song.getCell(0, 1, 0).param)) === 0x40);
  await page.keyboard.press('Control+Shift+z');
  check('Ctrl+Shift+Z redoes it', (await app(() => window.msxtrack.app.song.getCell(0, 1, 0).param)) === 0x42);

  // instrument editor
  await page.click('#ins-list button[data-i="2"]');
  check('instrument 2 selected', (await page.inputValue('#ins-name')) === 'PLUCK');
  const bar = await page.locator('#steps .bar[data-step="0"]').boundingBox();
  await page.mouse.move(bar.x + bar.width / 2, bar.y + bar.height * 0.5);
  await page.mouse.down();
  await page.mouse.up();
  const v0 = await app(() => window.msxtrack.app.song.stepByte(2, 0, 0));
  check('dragging the volume bar sets the volume', v0 >= 7 && v0 <= 8, `vol ${v0}`);

  // save .MTK, then open it again
  const [dl] = await Promise.all([page.waitForEvent('download'), page.click('#btn-save')]);
  const mtkPath = path.join(outDir, 'ui_test.mtk');
  await dl.saveAs(mtkPath);
  const bytes = fs.readFileSync(mtkPath);
  check('saved .MTK has the MSXTRACK header', bytes.subarray(0, 6).toString() === 'MSXTRK' && bytes[6] === 1);
  await page.click('#btn-new');
  await page.waitForFunction(() => window.msxtrack.app.song.name === 'SONG');
  check('New song', true);
  page.once('dialog', (d) => d.accept());
  await page.setInputFiles('#file-open', mtkPath);
  await page.waitForFunction(() => window.msxtrack.app.song.name === 'DEMO TUNE');
  const back = await app(() => window.msxtrack.app.song.getCell(0, 1, 0));
  check('reopened song keeps the edits', back.note === 49 && back.fx === 4 && back.param === 0x42);

  // export
  for (const fmt of ['mp3', 'wav']) {
    await page.click('#btn-export');
    await page.check(`input[name=fmt][value=${fmt}]`);
    const [d] = await Promise.all([page.waitForEvent('download', { timeout: 60000 }), page.click('#exp-go')]);
    const p = path.join(outDir, `ui_test.${fmt}`);
    await d.saveAs(p);
    const size = fs.statSync(p).size;
    check(`export ${fmt.toUpperCase()}`, size > 50000, `${size} bytes`);
    await page.click('#dlg-export button[value=cancel]');
  }

  check('no errors in the page', errors.length === 0, errors.join(' | '));
  await page.screenshot({ path: path.join(outDir, 'ui_test.png') });
  await browser.close();
  console.log(`RESULT fails=${fails}`);
  process.exit(fails ? 1 : 0);
})();
