import test from 'node:test';
import assert from 'node:assert/strict';
import { chromiumLaunchOptions } from '../tools/test-runtime.mjs';

const chromium = { executablePath: () => '/bundled/chromium' };
const resolve = (existing, env = {}, platform = 'linux') => chromiumLaunchOptions(chromium, {
  env, platform, executableExists: file => existing.includes(file)
});

test('explicit browser override wins over bundled and system browsers', () => {
  assert.deepEqual(resolve(['/custom/chrome', '/bundled/chromium', '/usr/bin/chromium'], { PN_CHROMIUM: '/custom/chrome' }), { executablePath: '/custom/chrome' });
});

test('invalid explicit browser override fails instead of silently changing browsers', () => {
  assert.throws(() => resolve(['/usr/bin/chromium'], { PN_CHROMIUM: '/missing/chrome' }), /PN_CHROMIUM does not identify an executable/);
});

test('installed Playwright browser keeps the pinned build without requiring a separate headless shell', () => {
  assert.deepEqual(resolve(['/bundled/chromium', '/usr/bin/chromium']), { executablePath: '/bundled/chromium' });
});

test('installed system Chromium works without PN_CHROMIUM or a download', () => {
  assert.deepEqual(resolve(['/usr/bin/chromium']), { executablePath: '/usr/bin/chromium' });
});

test('Windows browser discovery respects configured installation directories', () => {
  const browser = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  assert.deepEqual(resolve([browser], { PROGRAMFILES: 'C:\\Program Files' }, 'win32'), { executablePath: browser });
});

test('missing browser produces an actionable failure rather than weakening tests', () => {
  assert.throws(() => resolve([]), /No installed Chromium browser was found.*PN_CHROMIUM.*container/);
});
