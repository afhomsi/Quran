// Draws the app icon layers (full, bg, fg, mono, notif) from SVG with Playwright.
// Usage: cd tool/app_icon && node gen.js && python3 apply.py
const { chromium } = require('playwright');
const fs = require('fs');

// Text lines on the two pages of the open mushaf.
function pageLines(stroke, width, opacity) {
  let out = '';
  for (let i = 0; i < 4; i++) {
    const y = 468 + i * 34;
    out += `<path d="M${352 + i * 2} ${y - 6 + i} Q430 ${y - 20} 486 ${y}" stroke="${stroke}" stroke-opacity="${opacity}" stroke-width="${width}" stroke-linecap="round" fill="none"/>`;
    out += `<path d="M${672 - i * 2} ${y - 6 + i} Q594 ${y - 20} 538 ${y}" stroke="${stroke}" stroke-opacity="${opacity}" stroke-width="${width}" stroke-linecap="round" fill="none"/>`;
  }
  return out;
}

// mode: full (whole icon), bg (background layer), fg (foreground layer), mono (single colour)
function svg(mode, scale) {
  const mono = mode === 'mono' || mode === 'notif';
  const gold = mono ? '#fff' : 'url(#gold)';
  const page = mono ? '#fff' : 'url(#page)';
  const withBg = mode === 'full' || mode === 'bg';
  const bg = withBg ? `
    <rect width="1024" height="1024" fill="url(#bg)"/>
    <g opacity="0.10" stroke="#E9C46A" stroke-width="10" fill="none">
      <rect x="252" y="252" width="520" height="520" rx="18"/>
      <rect x="252" y="252" width="520" height="520" rx="18" transform="rotate(45 512 512)"/>
    </g>
    <circle cx="512" cy="512" r="430" fill="none" stroke="#E9C46A" stroke-opacity="0.12" stroke-width="6"/>` : '';
  const mask = mono ? `<mask id="cut"><rect width="1024" height="1024" fill="#fff"/>
      <path d="M512 446 L512 660" stroke="#000" stroke-width="16"/>
      ${pageLines('#000', 12, 1)}
      <circle cx="512" cy="300" r="22" fill="#000"/></mask>` : '';
  const content = mode === 'bg' ? '' : `
  <g transform="translate(512 512) scale(${scale}) translate(-512 -512)" ${mono ? 'mask="url(#cut)"' : ''}>
   <g filter="url(#sh)">
    <path d="M372 600 L652 790" stroke="${gold}" stroke-width="46" stroke-linecap="round"/>
    <path d="M652 600 L372 790" stroke="${gold}" stroke-width="46" stroke-linecap="round"/>
    <path d="M512 452 C450 412 370 404 296 420 L296 650 C370 634 450 640 512 682 C574 640 654 634 728 650 L728 420 C654 404 574 412 512 452 Z" fill="${gold}"/>
    <path d="M512 446 C454 404 384 392 322 404 L322 618 C384 608 454 618 512 656 Z" fill="${page}"/>
    <path d="M512 446 C570 404 640 392 702 404 L702 618 C640 608 570 618 512 656 Z" fill="${page}"/>
    ${mono ? '' : '<path d="M512 450 L512 652" stroke="#C99A3E" stroke-width="6"/>' + pageLines('#0F5B66', 9, 0.35)}
    <g fill="${gold}">
      <rect x="456" y="244" width="112" height="112" rx="6"/>
      <rect x="456" y="244" width="112" height="112" rx="6" transform="rotate(45 512 300)"/>
    </g>
    ${mono ? '' : '<circle cx="512" cy="300" r="30" fill="none" stroke="#0F5B66" stroke-width="10"/>'}
   </g>
  </g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#14808C"/><stop offset="1" stop-color="#083E47"/>
    </linearGradient>
    <linearGradient id="gold" gradientUnits="userSpaceOnUse" x1="0" y1="230" x2="0" y2="820">
      <stop offset="0" stop-color="#F6DA8A"/><stop offset="0.5" stop-color="#DDA847"/><stop offset="1" stop-color="#A8731F"/>
    </linearGradient>
    <linearGradient id="page" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFBEF"/><stop offset="1" stop-color="#F1E2BD"/>
    </linearGradient>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#00252B" flood-opacity="${mode === 'full' ? 0.45 : mode === 'fg' ? 0.3 : 0}"/>
    </filter>
    ${mask}
  </defs>
  ${bg}
  ${content}
</svg>`;
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const [name, scale, transparent] of [
    ['full', 1.08, false], ['bg', 1, false], ['fg', 0.86, true], ['mono', 0.86, true], ['notif', 1.4, true]]) {
    const s = svg(name, scale);
    fs.writeFileSync(name + '.svg', s);
    await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
    await p.screenshot({ path: name + '.png', omitBackground: transparent, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  await b.close();
})();
