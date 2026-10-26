import { test, expect } from '@playwright/test';

const approvedVisualTarget =
  process.env.PLAYWRIGHT_VISUAL_APPROVED === '1' &&
  Boolean(process.env.PLAYWRIGHT_BASE_URL);

test.describe('Project overview dashboard', () => {
  test.beforeEach(() => {
    test.skip(
      !approvedVisualTarget,
      'Set PLAYWRIGHT_VISUAL_APPROVED=1 and PLAYWRIGHT_BASE_URL to an approved deterministic visual environment.'
    );
  });

  test('matches approved desktop reference', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop-reference', 'Desktop reference only');

    await page.goto('/');
    await expect(page).toHaveTitle(/PLANNET|DOH|โครงการ/i);
    await expect(page.locator('h1.ptitle', { hasText: 'ภาพรวมโครงการ' })).toBeVisible();

    // The live-data dashboard has completed enough rendering when its hero is visible.
    await expect(page.locator('.dash-v25-hero-card')).toBeVisible();
    await page.addStyleTag({
      content: `
        *, *::before, *::after {
          animation: none !important;
          transition: none !important;
          caret-color: transparent !important;
        }
      `
    });

    await expect(page).toHaveScreenshot('dashboard-desktop.png', {
      fullPage: true,
      animations: 'disabled',
      maxDiffPixelRatio: 0.01
    });
  });

  test('keeps page layout inside the mobile viewport', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name === 'desktop-reference', 'Checked on touch layouts');

    await page.goto('/');
    await expect(page.locator('.dash-v25-hero-card')).toBeVisible();

    const dimensions = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth
    }));

    // Dashboard tables may scroll inside .table-scroll; the page itself may not.
    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth + 1);
  });
});
