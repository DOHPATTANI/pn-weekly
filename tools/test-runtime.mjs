import { accessSync, constants, statSync } from 'node:fs';
import path from 'node:path';

/** Check that a browser path is an executable file without launching it.
 * @param {string} executable Candidate executable path.
 * @returns {boolean} Whether the current user can execute the file.
 */
function canExecute(executable) {
  try {
    accessSync(executable, process.platform === 'win32' ? constants.F_OK : constants.X_OK);
    return statSync(executable).isFile();
  } catch {
    return false;
  }
}

/** Resolve test-only Chromium launch options without downloading a browser.
 * Explicit PN_CHROMIUM wins; an installed Playwright browser keeps the pinned
 * browser build used by CI. Select its full executable explicitly because a
 * no-shell installation may omit Playwright's separate default headless shell.
 * A system Chromium is a local fallback only.
 * @param {{executablePath: () => string}} chromium Playwright Chromium browser type.
 * @param {{env?: object, platform?: string, executableExists?: (file: string) => boolean}} [options] Test seams and runtime selectors.
 * @returns {{executablePath?: string}} Options to merge into chromium.launch or Playwright launchOptions.
 * @throws {Error} When an explicit override is invalid or no installed browser is available.
 */
export function chromiumLaunchOptions(chromium, options = {}) {
  const env = options.env ?? process.env;
  const platform = options.platform ?? process.platform;
  const executableExists = options.executableExists ?? canExecute;
  if (env.PN_CHROMIUM) {
    if (!executableExists(env.PN_CHROMIUM)) {
      throw new Error('PN_CHROMIUM does not identify an executable browser. Correct its path or unset it to use an installed Playwright/system Chromium.');
    }
    return { executablePath: env.PN_CHROMIUM };
  }
  const bundledPath = chromium.executablePath();
  if (executableExists(bundledPath)) return { executablePath: bundledPath };
  const candidates = platform === 'win32'
    ? [env.PROGRAMFILES, env['PROGRAMFILES(X86)'], env.LOCALAPPDATA]
      .filter(Boolean).flatMap(base => [
        path.win32.join(base, 'Google', 'Chrome', 'Application', 'chrome.exe'),
        path.win32.join(base, 'Microsoft', 'Edge', 'Application', 'msedge.exe')
      ])
    : platform === 'darwin'
      ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium']
      : ['/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome', '/opt/google/chrome/chrome'];
  const executablePath = candidates.find(executableExists);
  if (executablePath) return { executablePath };
  throw new Error('No installed Chromium browser was found. Set PN_CHROMIUM to an installed browser executable, install the matching Playwright Chromium in an authorized environment, or use the repository Playwright container. No browser was downloaded automatically.');
}
