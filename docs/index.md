---
title: Ball tracking on your iPhone
description: TrueLine tracks your bowling ball with your iPhone. Speed, hook, breakpoint, and entry angle for every throw, with no extra hardware.
---

<style>
.hero { margin-top: 2.5rem; }
.hero h1 { font-size: 2rem; margin: 0 0 0.75rem; }
.hero .lede { font-size: 1.1rem; color: var(--muted); max-width: 34rem; }
.phone-art { display: block; margin: 2.5rem auto 0; max-width: 280px; width: 74%; }
.cta-block {
  margin: 2.5rem 0;
  padding: 1.5rem;
  border: 1px solid var(--rule);
  border-radius: 16px;
  text-align: center;
}
.cta-block p { margin: 0 0 1rem; }
.cta-button {
  display: inline-block;
  background: var(--accent);
  color: var(--bg);
  font-weight: 600;
  text-decoration: none;
  padding: 0.8rem 1.6rem;
  border-radius: 999px;
}
.cta-button:hover { opacity: 0.9; }
.cta-button:disabled { opacity: 0.6; }
.cta-note { font-size: 0.85rem; color: var(--muted); margin-top: 0.75rem !important; }
.notify-form { display: flex; gap: 0.6rem; justify-content: center; flex-wrap: wrap; }
.notify-input {
  font: inherit;
  font-size: 16px; /* ≥16px stops iOS Safari zooming the page on focus */
  color: var(--ink);
  background: var(--bg);
  border: 1px solid var(--rule);
  border-radius: 999px;
  padding: 0.75rem 1.2rem;
  min-width: 0;
  flex: 1 1 12rem;
  max-width: 18rem;
}
.notify-input:focus { outline: 2px solid var(--accent); outline-offset: 1px; border-color: transparent; }
.cta-button { border: 0; cursor: pointer; font-size: 16px; }
.notify-done { color: var(--accent); font-weight: 600; font-size: 1.05rem; }
.metrics { list-style: none; padding: 0; display: grid; grid-template-columns: 1fr 1fr; gap: 0.4rem 1.5rem; }
.metrics li { padding-left: 1.1rem; text-indent: -1.1rem; }
.metrics li::before { content: "◆ "; color: var(--accent); font-size: 0.7em; }
@media (max-width: 480px) { .metrics { grid-template-columns: 1fr; } }
.phone-row { display: flex; gap: 1.25rem; justify-content: center; margin: 1.75rem 0 0.5rem; }
.phone-col { flex: 1 1 0; max-width: 215px; margin: 0; }
.phone-col svg { width: 100%; height: auto; display: block; }
.phone-col figcaption { font-size: 0.85rem; font-weight: 600; color: var(--muted); text-align: center; margin-top: 0.75rem; letter-spacing: 0.01em; }
.steps li { margin-bottom: 0.6rem; }
</style>

<div class="hero">
<h1>See what your ball actually did.</h1>
<p class="lede">TrueLine tracks your bowling ball with your iPhone. Prop the phone up behind the approach and bowl like you normally would. A few seconds after each throw, you get the numbers a coach would give you.</p>
</div>

<svg class="phone-art" viewBox="0 0 260 520" fill="none" aria-label="iPhone showing TrueLine's Shot Result screen: a narrow top-down lane with the tracked hook path, and stat tiles for speed, hook, entry angle, and breakpoint">
  <rect x="6" y="6" width="248" height="508" rx="42" fill="#1c1c1e" stroke="#3a3a3e" stroke-width="2"/>
  <rect x="16" y="16" width="228" height="488" rx="33" fill="#0e0e10"/>
  <rect x="102" y="26" width="56" height="15" rx="7.5" fill="#000000"/>
  <text x="130" y="60" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="12" font-weight="700" fill="#ececee">Shot Result</text>
  <rect x="76" y="74" width="108" height="330" rx="10" fill="#141416"/>
  <rect x="94.5" y="112" width="3.5" height="274" fill="#262628"/>
  <rect x="162" y="112" width="3.5" height="274" fill="#262628"/>
  <rect x="98" y="112" width="64" height="274" fill="#37373c" stroke="#464b50" stroke-width="1"/>
  <g stroke="#41464b" stroke-width="0.6">
    <line x1="146.8" y1="112" x2="146.8" y2="386"/>
    <line x1="130.0" y1="112" x2="130.0" y2="386"/>
    <line x1="113.2" y1="112" x2="113.2" y2="386"/>
  </g>
  <rect x="98" y="87.4" width="64" height="24.6" fill="#232326"/>
  <rect x="133.4" y="112.0" width="1.7" height="54.8" fill="#40e69e" opacity="0.14"/>
  <line x1="134.7" y1="112.0" x2="134.7" y2="166.8" stroke="#29946b" stroke-width="0.7" stroke-dasharray="2.5 3.5"/>
  <line x1="98" y1="386.0" x2="162" y2="386.0" stroke="#29946b" stroke-width="1.5"/>
  <line x1="98" y1="358.6" x2="162" y2="358.6" stroke="#29946b" stroke-width="0.7" stroke-dasharray="3.5 3"/>
  <line x1="98" y1="112.0" x2="162" y2="112.0" stroke="#29946b" stroke-width="1.2"/>
  <polyline points="155.3,331.2 146.8,325.1 138.4,319.0 130.0,312.9 121.6,319.0 113.2,325.1 104.7,331.2" stroke="#29946b" stroke-width="0.7"/>
  <g fill="#40e69e">
    <path d="M155.3 329.0 L153.5 332.8 L157.1 332.8 Z"/>
    <path d="M146.8 322.9 L145.0 326.7 L148.6 326.7 Z"/>
    <path d="M138.4 316.8 L136.6 320.6 L140.2 320.6 Z"/>
    <path d="M130.0 310.7 L128.2 314.5 L131.8 314.5 Z"/>
    <path d="M121.6 316.8 L119.8 320.6 L123.4 320.6 Z"/>
    <path d="M113.2 322.9 L111.4 326.7 L115.0 326.7 Z"/>
    <path d="M104.7 329.0 L102.9 332.8 L106.5 332.8 Z"/>
  </g>
  <circle cx="130.0" cy="112.0" r="2.1" fill="#40e69e" stroke="#292929" stroke-width="0.6"/>
  <circle cx="139.5" cy="105.5" r="2.1" fill="#40e69e" stroke="#292929" stroke-width="0.6"/>
  <circle cx="120.5" cy="105.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="149.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="130.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="111.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="158.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="139.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="120.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="101.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <path d="M133.4 386.0 L134.7 379.1 L136.0 372.3 L137.2 365.5 L138.4 358.6 L139.5 351.8 L140.6 344.9 L141.6 338.0 L142.6 331.2 L143.5 324.4 L144.4 317.5 L145.3 310.6 L146.1 303.8 L146.8 297.0 L147.5 290.1 L148.2 283.2 L148.8 276.4 L149.3 269.5 L149.8 262.7 L150.3 255.8 L150.7 249.0 L151.1 242.2 L151.4 235.3 L151.6 228.5 L151.8 221.6 L152.0 214.8 L152.1 207.9 L152.2 201.0 L152.2 194.2 L151.5 187.4 L150.6 180.5 L149.6 173.6 L148.5 166.8 L147.2 160.0 L145.8 153.1 L144.3 146.2 L142.6 139.4 L140.8 132.5 L138.8 125.7 L136.8 118.9 L134.5 112.0" stroke="#40e69e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M139.3 316.8 L136.7 321.7 L141.9 321.7 Z" fill="#40e69e" stroke="#ffffff" stroke-width="0.5"/>
  <circle cx="152.2" cy="194.2" r="2.8" fill="#40e69e"/>
  <rect x="158.2" y="188.7" width="19" height="11" rx="5.5" fill="#000000" opacity="0.6"/>
  <text x="167.7" y="196.6" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="7" font-weight="600" fill="#ffffff">6.8</text>
  <g font-family="-apple-system, Helvetica, sans-serif">
    <rect x="28" y="414" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="427" font-size="7.5" fill="#98989f">Speed</text>
    <text x="37" y="443" font-size="14" font-weight="700" fill="#ececee">17.2 <tspan font-size="7.5" font-weight="400" fill="#98989f">mph</tspan></text>
    <rect x="134" y="414" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="143" y="427" font-size="7.5" fill="#98989f">Hook</text>
    <text x="143" y="443" font-size="14" font-weight="700" fill="#ececee">10.5 <tspan font-size="7.5" font-weight="400" fill="#98989f">boards</tspan></text>
    <rect x="28" y="460" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="473" font-size="7.5" fill="#98989f">Entry Angle</text>
    <text x="37" y="489" font-size="14" font-weight="700" fill="#40e69e">4.8 <tspan font-size="7.5" font-weight="400" fill="#98989f">°</tspan></text>
    <text x="84" y="489" font-size="6" fill="#40e69e" opacity="0.85">target 4–6</text>
    <rect x="134" y="460" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="143" y="473" font-size="7.5" fill="#98989f">Breakpoint</text>
    <text x="143" y="489" font-size="14" font-weight="700" fill="#ececee">6.8 <tspan font-size="7.5" font-weight="400" fill="#98989f">board</tspan></text>
  </g>
</svg>

<div class="cta-block">
<p><strong>TrueLine is coming to the App Store.</strong></p>
<form id="notify-form" class="notify-form" action="https://formspree.io/f/mlgqdanz" method="POST">
  <input class="notify-input" type="email" name="email" required placeholder="you@example.com" autocomplete="email" aria-label="Email address">
  <button class="cta-button" type="submit">Get notified</button>
</form>
<p class="cta-note">You'll get one email when it launches and that's it. Want to try the beta before then? Ask on the <a href="support.md">Support page</a>.</p>
<p class="cta-note" id="notify-fail" hidden>That didn't go through. Try again in a minute, or use the form on the <a href="support.md">Support page</a>.</p>
</div>

<script>
(function () {
  var form = document.getElementById("notify-form");
  if (!form) return;
  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var btn = form.querySelector("button");
    btn.disabled = true;
    btn.textContent = "Signing up…";
    fetch(form.action, {
      method: "POST",
      body: new FormData(form),
      headers: { Accept: "application/json" },
    }).then(function (r) {
      if (!r.ok) { throw new Error("bad status"); }
      form.innerHTML = '<p class="notify-done">✓ You’re on the list.</p>';
    }).catch(function () {
      btn.disabled = false;
      btn.textContent = "Get notified";
      document.getElementById("notify-fail").hidden = false;
    });
  });
})();
</script>

## What it measures

<ul class="metrics">
<li>Ball speed</li>
<li>Board at the arrows</li>
<li>Launch angle</li>
<li>Breakpoint board &amp; distance</li>
<li>Entry board &amp; entry angle</li>
<li>Total hook, in boards</li>
<li>Pocket hits</li>
<li>Trends across sessions</li>
</ul>

Each shot gets replayed with the tracked line drawn over your video. A whole session stacks up on one lane view so you can see how your line moved through the night. If you bowl more than one ball, you can compare them by speed, hook, and pocket rate.

<div class="phone-row">
<figure class="phone-col">
<svg viewBox="0 0 260 520" fill="none" aria-label="iPhone showing a TrueLine session: every throw of the session fanned on one lane view, plus session stats">
  <rect x="6" y="6" width="248" height="508" rx="42" fill="#1c1c1e" stroke="#3a3a3e" stroke-width="2"/>
  <rect x="16" y="16" width="228" height="488" rx="33" fill="#0e0e10"/>
  <rect x="102" y="26" width="56" height="15" rx="7.5" fill="#000000"/>
  <text x="130" y="60" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="12" font-weight="700" fill="#ececee">Jul 14 · 7:12 PM</text>
  <rect x="76" y="74" width="108" height="330" rx="10" fill="#141416"/>
  <rect x="94.5" y="112" width="3.5" height="274" fill="#262628"/>
  <rect x="162" y="112" width="3.5" height="274" fill="#262628"/>
  <rect x="98" y="112" width="64" height="274" fill="#37373c" stroke="#464b50" stroke-width="1"/>
  <g stroke="#41464b" stroke-width="0.6">
    <line x1="146.8" y1="112" x2="146.8" y2="386"/>
    <line x1="130.0" y1="112" x2="130.0" y2="386"/>
    <line x1="113.2" y1="112" x2="113.2" y2="386"/>
  </g>
  <rect x="98" y="87.4" width="64" height="24.6" fill="#232326"/>
  <rect x="133.4" y="112.0" width="1.7" height="54.8" fill="#40e69e" opacity="0.14"/>
  <line x1="98" y1="386.0" x2="162" y2="386.0" stroke="#29946b" stroke-width="1.5"/>
  <line x1="98" y1="358.6" x2="162" y2="358.6" stroke="#29946b" stroke-width="0.7" stroke-dasharray="3.5 3"/>
  <line x1="98" y1="112.0" x2="162" y2="112.0" stroke="#29946b" stroke-width="1.2"/>
  <polyline points="155.3,331.2 146.8,325.1 138.4,319.0 130.0,312.9 121.6,319.0 113.2,325.1 104.7,331.2" stroke="#29946b" stroke-width="0.7"/>
  <g fill="#40e69e">
    <path d="M155.3 329.0 L153.5 332.8 L157.1 332.8 Z"/>
    <path d="M146.8 322.9 L145.0 326.7 L148.6 326.7 Z"/>
    <path d="M138.4 316.8 L136.6 320.6 L140.2 320.6 Z"/>
    <path d="M130.0 310.7 L128.2 314.5 L131.8 314.5 Z"/>
    <path d="M121.6 316.8 L119.8 320.6 L123.4 320.6 Z"/>
    <path d="M113.2 322.9 L111.4 326.7 L115.0 326.7 Z"/>
    <path d="M104.7 329.0 L102.9 332.8 L106.5 332.8 Z"/>
  </g>
  <circle cx="130.0" cy="112.0" r="2.1" fill="#40e69e" stroke="#292929" stroke-width="0.6"/>
  <circle cx="139.5" cy="105.5" r="2.1" fill="#40e69e" stroke="#292929" stroke-width="0.6"/>
  <circle cx="120.5" cy="105.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="149.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="130.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="111.0" cy="99.0" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="158.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="139.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="120.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <circle cx="101.5" cy="92.5" r="2.1" fill="#dbdbde" stroke="#292929" stroke-width="0.6"/>
  <path d="M124.9 386.0 L125.9 379.1 L126.9 372.3 L127.8 365.5 L128.6 358.6 L129.5 351.8 L130.3 344.9 L131.1 338.0 L131.8 331.2 L132.5 324.4 L133.2 317.5 L133.9 310.6 L134.5 303.8 L135.1 297.0 L135.6 290.1 L136.1 283.2 L136.6 276.4 L137.1 269.5 L137.5 262.7 L137.9 255.8 L138.3 249.0 L138.6 242.2 L138.9 235.3 L139.2 228.5 L139.4 221.6 L139.6 214.8 L139.8 207.9 L139.9 201.0 L140.0 194.2 L140.1 187.4 L140.1 180.5 L140.0 173.6 L139.8 166.8 L139.5 160.0 L139.1 153.1 L138.7 146.2 L138.3 139.4 L137.8 132.5 L137.2 125.7 L136.6 118.9 L135.9 112.0" stroke="#40e69e" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.2"/>
  <path d="M138.4 386.0 L139.3 379.1 L140.1 372.3 L140.9 365.5 L141.6 358.6 L142.3 351.8 L143.0 344.9 L143.6 338.0 L144.2 331.2 L144.8 324.4 L145.3 317.5 L145.8 310.6 L146.3 303.8 L146.7 297.0 L147.1 290.1 L147.4 283.2 L147.7 276.4 L148.0 269.5 L148.2 262.7 L148.4 255.8 L148.6 249.0 L148.7 242.2 L148.8 235.3 L148.8 228.5 L148.9 221.6 L148.2 214.8 L147.4 207.9 L146.5 201.0 L145.5 194.2 L144.4 187.4 L143.2 180.5 L141.9 173.6 L140.5 166.8 L139.0 160.0 L137.4 153.1 L135.7 146.2 L133.9 139.4 L132.0 132.5 L130.1 125.7 L128.0 118.9 L125.8 112.0" stroke="#40e69e" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.28"/>
  <path d="M130.8 386.0 L132.6 379.1 L134.3 372.3 L136.0 365.5 L137.6 358.6 L139.1 351.8 L140.6 344.9 L142.0 338.0 L143.3 331.2 L144.6 324.4 L145.8 317.5 L147.0 310.6 L148.1 303.8 L149.1 297.0 L150.1 290.1 L151.0 283.2 L151.8 276.4 L152.6 269.5 L153.3 262.7 L154.0 255.8 L154.6 249.0 L155.2 242.2 L155.6 235.3 L156.1 228.5 L156.4 221.6 L156.7 214.8 L156.9 207.9 L157.1 201.0 L157.2 194.2 L157.3 187.4 L156.8 180.5 L156.1 173.6 L155.1 166.8 L154.1 160.0 L152.9 153.1 L151.5 146.2 L150.0 139.4 L148.4 132.5 L146.6 125.7 L144.7 118.9 L142.6 112.0" stroke="#40e69e" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.36"/>
  <path d="M134.7 386.0 L135.8 379.1 L136.9 372.3 L137.9 365.5 L138.9 358.6 L139.9 351.8 L140.8 344.9 L141.6 338.0 L142.4 331.2 L143.2 324.4 L144.0 317.5 L144.6 310.6 L145.3 303.8 L145.9 297.0 L146.5 290.1 L147.0 283.2 L147.4 276.4 L147.9 269.5 L148.3 262.7 L148.6 255.8 L148.9 249.0 L149.2 242.2 L149.4 235.3 L149.6 228.5 L149.7 221.6 L149.8 214.8 L149.9 207.9 L149.7 201.0 L149.2 194.2 L148.6 187.4 L148.0 180.5 L147.2 173.6 L146.4 166.8 L145.5 160.0 L144.5 153.1 L143.4 146.2 L142.3 139.4 L141.1 132.5 L139.8 125.7 L138.4 118.9 L136.9 112.0" stroke="#40e69e" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.44"/>
  <path d="M133.4 386.0 L134.7 379.1 L136.0 372.3 L137.2 365.5 L138.4 358.6 L139.5 351.8 L140.6 344.9 L141.6 338.0 L142.6 331.2 L143.5 324.4 L144.4 317.5 L145.3 310.6 L146.1 303.8 L146.8 297.0 L147.5 290.1 L148.2 283.2 L148.8 276.4 L149.3 269.5 L149.8 262.7 L150.3 255.8 L150.7 249.0 L151.1 242.2 L151.4 235.3 L151.6 228.5 L151.8 221.6 L152.0 214.8 L152.1 207.9 L152.2 201.0 L152.2 194.2 L151.5 187.4 L150.6 180.5 L149.6 173.6 L148.5 166.8 L147.2 160.0 L145.8 153.1 L144.3 146.2 L142.6 139.4 L140.8 132.5 L138.8 125.7 L136.8 118.9 L134.5 112.0" stroke="#40e69e" stroke-width="2.0" stroke-linecap="round" stroke-linejoin="round"/>
  <g font-family="-apple-system, Helvetica, sans-serif">
    <rect x="28" y="414" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="427" font-size="7.5" fill="#98989f">Pocket Hits</text>
    <text x="37" y="443" font-size="13" font-weight="700" fill="#ececee">6 <tspan font-size="7.5" font-weight="400" fill="#98989f">of 9</tspan></text>
    <rect x="134" y="414" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="143" y="427" font-size="7.5" fill="#98989f">Avg Speed</text>
    <text x="143" y="443" font-size="13" font-weight="700" fill="#ececee">16.9 <tspan font-size="7.5" font-weight="400" fill="#98989f">mph</tspan></text>
  </g>
  <text x="130" y="470" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="6.5" fill="#98989f">Brighter lines are more recent throws.</text>
</svg>
<figcaption>Session view</figcaption>
</figure>
<figure class="phone-col">
<svg viewBox="0 0 260 520" fill="none" aria-label="iPhone showing TrueLine's Stats tab: all-time totals, averages, and trend charts across sessions">
  <rect x="6" y="6" width="248" height="508" rx="42" fill="#1c1c1e" stroke="#3a3a3e" stroke-width="2"/>
  <rect x="16" y="16" width="228" height="488" rx="33" fill="#0e0e10"/>
  <rect x="102" y="26" width="56" height="15" rx="7.5" fill="#000000"/>
  <g font-family="-apple-system, Helvetica, sans-serif">
  <text x="30" y="64" font-size="15" font-weight="800" fill="#ececee">Stats</text>
  <text x="30" y="106" font-size="32" font-weight="800" fill="#ececee">127</text>
  <text x="30" y="120" font-size="9" font-weight="600" fill="#40e69e">throws measured</text>
  <text x="30" y="132" font-size="7.5" fill="#98989f">9 sessions · 6 days bowled</text>
    <rect x="28" y="142" width="65" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="155" font-size="7.5" fill="#98989f">Avg Speed</text>
    <text x="37" y="171" font-size="11" font-weight="700" fill="#ececee">16.8 <tspan font-size="7.5" font-weight="400" fill="#98989f">mph</tspan></text>
    <rect x="97.5" y="142" width="65" height="40" rx="9" fill="#1d1d21"/>
    <text x="106.5" y="155" font-size="7.5" fill="#98989f">Avg Hook</text>
    <text x="106.5" y="171" font-size="11" font-weight="700" fill="#ececee">9.2 <tspan font-size="7.5" font-weight="400" fill="#98989f">bds</tspan></text>
    <rect x="167" y="142" width="65" height="40" rx="9" fill="#1d1d21"/>
    <text x="176" y="155" font-size="7.5" fill="#98989f">Pocket</text>
    <text x="176" y="171" font-size="11" font-weight="700" fill="#ececee">54 <tspan font-size="7.5" font-weight="400" fill="#98989f">%</tspan></text>
  <text x="30" y="206" font-size="11" font-weight="700" fill="#ececee">Trends</text>
    <rect x="28" y="216" width="204" height="118" rx="10" fill="#1d1d21"/>
    <text x="40" y="233" font-size="8" fill="#98989f">Speed <tspan fill="#98989f" font-size="7">(mph)</tspan></text>
    <line x1="40" y1="294.7" x2="220" y2="294.7" stroke="#2a2a2e" stroke-width="0.6"/>
    <line x1="40" y1="269.3" x2="220" y2="269.3" stroke="#2a2a2e" stroke-width="0.6"/>
    <polyline points="40.0,302.7 65.7,288.9 91.4,295.8 117.1,271.6 142.9,282.0 168.6,264.7 194.3,257.8 220.0,261.3" stroke="#40e69e" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="40.0" cy="302.7" r="1.8" fill="#40e69e"/>
    <circle cx="65.7" cy="288.9" r="1.8" fill="#40e69e"/>
    <circle cx="91.4" cy="295.8" r="1.8" fill="#40e69e"/>
    <circle cx="117.1" cy="271.6" r="1.8" fill="#40e69e"/>
    <circle cx="142.9" cy="282.0" r="1.8" fill="#40e69e"/>
    <circle cx="168.6" cy="264.7" r="1.8" fill="#40e69e"/>
    <circle cx="194.3" cy="257.8" r="1.8" fill="#40e69e"/>
    <circle cx="220.0" cy="261.3" r="1.8" fill="#40e69e"/>
    <rect x="28" y="344" width="204" height="118" rx="10" fill="#1d1d21"/>
    <text x="40" y="361" font-size="8" fill="#98989f">Entry Angle <tspan fill="#98989f" font-size="7">(°)</tspan></text>
    <rect x="40" y="381.5" width="180" height="38.0" fill="#40e69e" opacity="0.12"/>
    <line x1="40" y1="422.7" x2="220" y2="422.7" stroke="#2a2a2e" stroke-width="0.6"/>
    <line x1="40" y1="397.3" x2="220" y2="397.3" stroke="#2a2a2e" stroke-width="0.6"/>
    <polyline points="40.0,436.6 65.7,427.1 91.4,415.7 117.1,421.4 142.9,408.1 168.6,402.4 194.3,398.6 220.0,404.3" stroke="#40e69e" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="40.0" cy="436.6" r="1.8" fill="#40e69e"/>
    <circle cx="65.7" cy="427.1" r="1.8" fill="#40e69e"/>
    <circle cx="91.4" cy="415.7" r="1.8" fill="#40e69e"/>
    <circle cx="117.1" cy="421.4" r="1.8" fill="#40e69e"/>
    <circle cx="142.9" cy="408.1" r="1.8" fill="#40e69e"/>
    <circle cx="168.6" cy="402.4" r="1.8" fill="#40e69e"/>
    <circle cx="194.3" cy="398.6" r="1.8" fill="#40e69e"/>
    <circle cx="220.0" cy="404.3" r="1.8" fill="#40e69e"/>
  </g>
</svg>
<figcaption>Stats</figcaption>
</figure>
</div>

## How it works

<ol class="steps">
<li>Prop your phone behind the approach so it can see the whole lane.</li>
<li>Set the four lane corners once. After that you just bowl.</li>
<li>Your numbers show up a few seconds after each throw.</li>
</ol>

There's no hardware to buy and nothing to set up at the center. It works at any house, and it can also analyze footage already in your camera roll.

## Nothing leaves your phone

TrueLine has no accounts and makes no network requests. All of the analysis runs on the phone itself. The first 10 throws are free, and a single purchase unlocks it for good.

Questions? See [Support](support.md) or read the [Privacy Policy](privacy.md).
