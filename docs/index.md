---
title: Every throw, measured
description: TrueLine turns your iPhone into a bowling ball-motion tracker — speed, board at the arrows, breakpoint, entry angle, and hook for every throw. No hardware, no subscription.
---

<style>
.hero { margin-top: 2.5rem; }
.hero h1 { font-size: 2rem; margin: 0 0 0.75rem; }
.hero .lede { font-size: 1.1rem; color: var(--muted); max-width: 34rem; }
.phone-art { display: block; margin: 2.5rem auto 0; max-width: 280px; width: 74%; }
.art-caption { text-align: center; font-size: 0.85rem; color: var(--muted); margin-top: 0.75rem; }
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
.steps li { margin-bottom: 0.6rem; }
</style>

<div class="hero">
<h1>Every throw, measured.</h1>
<p class="lede">TrueLine turns your iPhone into a bowling ball-motion tracker. Prop your phone behind the approach, bowl, and get the numbers a coach would give you — for every single throw, in seconds.</p>
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
<p class="art-caption">One throw in TrueLine — tracked, measured, scored.</p>

<div class="cta-block">
<p><strong>TrueLine is coming to the App Store.</strong></p>
<form id="notify-form" class="notify-form" action="https://formspree.io/f/mlgqdanz" method="POST">
  <input class="notify-input" type="email" name="email" required placeholder="you@example.com" autocomplete="email" aria-label="Email address">
  <button class="cta-button" type="submit">Get notified</button>
</form>
<p class="cta-note">One email when it ships — nothing else. Want to try it early?
Say so on the <a href="support.md">Support page</a> and you're on the TestFlight beta list.</p>
<p class="cta-note" id="notify-fail" hidden>That didn't go through — please try again in a minute, or use the form on the <a href="support.md">Support page</a>.</p>
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

## What you get, every throw

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

Your throw is replayed with the tracked path drawn on it, every line of a session fans onto one lane view, and you can compare your arsenal ball by ball — speed, hook, and pocket rate.

## How it works

<ol class="steps">
<li><strong>Prop your phone</strong> behind the approach, looking down your lane.</li>
<li><strong>Set the lane corners once</strong> — then just bowl.</li>
<li><strong>Get your numbers in seconds</strong>, throw after throw.</li>
</ol>

No hardware, no lane sensors, and it works at any center. You can also analyze footage already in your camera roll.

## Private by design

Everything runs on your iPhone. No account, no cloud, no subscription — TrueLine makes zero network requests. Your first 10 throws are free; one purchase unlocks it forever.

Questions? See [Support](support.md) or read the [Privacy Policy](privacy.md).
