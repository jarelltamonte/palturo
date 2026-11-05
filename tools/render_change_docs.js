const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  async function render(file, out) {
    const page = await browser.newPage();
    await page.goto('file:///' + path.resolve(file).replace(/\\/g, '/'), { waitUntil: 'load' });
    await page.emulateMedia({ media: 'print' });
    await page.waitForTimeout(800);
    await page.pdf({
      path: out,
      format: 'A4',
      printBackground: true,
      margin: { top: '0', bottom: '0', left: '0', right: '0' },
      displayHeaderFooter: false,
    });
    await page.close();
  }
  await render('docs/_cover.html', 'docs/_cover.pdf');
  await render('docs/_content.html', 'docs/_content.pdf');
  await browser.close();
  console.log('cover', fs.statSync('docs/_cover.pdf').size, 'content', fs.statSync('docs/_content.pdf').size);
})();
