const puppeteer = require('puppeteer');

(async () => {
  const out = process.argv[2] || 'assets/screenshots/loading-menu.png';
  const url = process.argv[3] || 'http://127.0.0.1:8799/index.html?v=readme-shot';
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });
    const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await wait(1200);
    await page.mouse.click(640, 360);
    await wait(6000);
    await page.screenshot({ path: out, fullPage: true });
    console.log(`screenshot=${out}`);
  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error(err);
  process.exit(1);
});
