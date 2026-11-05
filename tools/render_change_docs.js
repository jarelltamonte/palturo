const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1200, height: 1600 } });
  const file = path.resolve('docs/PalTuro-Dynamic-UX-Changes.html');
  await page.goto('file:///' + file.replace(/\\/g, '/'), { waitUntil: 'load' });
  await page.emulateMedia({ media: 'print' });
  await page.waitForTimeout(900);
  await page.pdf({
    path: 'docs/PalTuro-Dynamic-UX-Changes.pdf',
    printBackground: true,
    preferCSSPageSize: true,
    margin: { top: '0', bottom: '0', left: '0', right: '0' },
  });
  await browser.close();
  console.log('pdf', fs.statSync('docs/PalTuro-Dynamic-UX-Changes.pdf').size);
})();
