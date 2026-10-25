import fs from 'node:fs/promises';
import http from 'node:http';
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

// Isolate shared shell interactions; full app/data regression remains owned by tools.mjs qa.
const html = await fs.readFile('index.html', 'utf8');
const css = await fs.readFile('styles.css', 'utf8');
const js = await fs.readFile('src/sidebar.js', 'utf8');
const server = http.createServer((req, res) => {
  const file = req.url.split('?')[0];
  res.setHeader('Content-Type', file === '/styles.css' ? 'text/css' : file === '/app.js' ? 'text/javascript' : 'text/html');
  res.end(file === '/styles.css' ? css : file === '/app.js' ? js : html);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({headless:true,...(process.env.PN_CHROMIUM ? {executablePath:process.env.PN_CHROMIUM} : {})});
const base = 'http://127.0.0.1:' + server.address().port;
try {
  const context = await browser.newContext({viewport:{width:1440,height:1000}});
  const page = await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base);
  const sidebar=page.locator("#app-sidebar"),toggle=page.locator("#sidebar-toggle");
  await page.waitForFunction(()=>document.querySelector("#app-sidebar").dataset.interactionMounted);
  assert.equal(await page.locator("#sidebar-search-input").count(),0);
  await toggle.click();await page.waitForFunction(()=>document.querySelector(".sidebar").classList.contains("is-collapsed"));
  await page.reload();await page.waitForFunction(()=>document.querySelector(".sidebar").classList.contains("is-collapsed"));
  await page.locator("#app").evaluate(el=>{el.dataset.screen="dashboard";el.innerHTML="<input id=search aria-label=Search>";});
  for(const key of ["Control+k","Meta+k"]){await page.keyboard.press(key);assert.equal(await page.locator("#search").evaluate(el=>document.activeElement===el),true);}
  assert.equal(await page.locator(".tour-overlay").count(),0);await page.locator("#sidebar-help").click();await page.locator(".tour-overlay").waitFor();await page.keyboard.press("Escape");assert.equal(await page.locator(".tour-overlay").count(),0);
  await page.setViewportSize({width:375,height:812});await page.waitForFunction(()=>!document.querySelector('.sidebar').classList.contains('is-collapsed'));await page.locator(".sidebar").evaluate(el=>el.classList.add("open"));await toggle.click();assert.equal(await sidebar.evaluate(el=>el.classList.contains("open")),false);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false);
  await context.close();
  const restricted=await browser.newContext({viewport:{width:1200,height:850},reducedMotion:'reduce'});
  await restricted.addInitScript(()=>{Storage.prototype.setItem=()=>{throw new Error('storage unavailable')};Storage.prototype.getItem=()=>{throw new Error('storage unavailable')};});
  const reduced=await restricted.newPage();reduced.on('pageerror',e=>errors.push(e.message));await reduced.goto(base);
  await reduced.evaluate(()=>{window.sidebarResizeEvents=0;window.addEventListener('resize',()=>window.sidebarResizeEvents++);});
  await reduced.locator('#sidebar-toggle').click();
  await reduced.waitForFunction(()=>window.sidebarResizeEvents>0);
  assert.equal(await reduced.locator('.sidebar').evaluate(el=>el.classList.contains('is-collapsed')),true);
  assert.equal(await reduced.locator('.sidebar').evaluate(el=>getComputedStyle(el).transitionDuration),'0s');
  await fs.mkdir('work/sidebar',{recursive:true});
  await reduced.screenshot({path:'work/sidebar/collapsed.png'});
  await reduced.locator('#sidebar-toggle').click();await reduced.screenshot({path:'work/sidebar/expanded.png'});
  assert.deepEqual(errors,[]);
  console.log('Sidebar passed: persisted collapse, page search Ctrl/Cmd+K, manual contextual help, Escape close, mobile drawer, reduced motion, storage failure.');
  await restricted.close();
} finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
