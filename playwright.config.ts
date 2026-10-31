import { defineConfig, devices, chromium } from '@playwright/test';
import { chromiumLaunchOptions } from './tools/test-runtime.mjs';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://127.0.0.1:4173';

export default defineConfig({
  testDir: './tests/visual',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
    toHaveScreenshot: { maxDiffPixelRatio: 0.01 }
  },
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    browserName: 'chromium',
    headless: true,
    launchOptions: chromiumLaunchOptions(chromium),
    viewport: { width: 2048, height: 1143 },
    deviceScaleFactor: 1,
    colorScheme: 'light',
    locale: 'th-TH',
    timezoneId: 'Asia/Bangkok',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure'
  },
  projects: [
    {
      name: 'desktop-reference',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 2048, height: 1143 },
        deviceScaleFactor: 1
      }
    },
    {
      name: 'mobile-390',
      use: {
        ...devices['iPhone 13'],
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 1
      }
    },
    {
      name: 'tablet-768',
      use: {
        ...devices['iPad Mini'],
        viewport: { width: 768, height: 1024 },
        deviceScaleFactor: 1
      }
    }
  ],
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: 'PORT=4173 npm start',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000
      }
});
