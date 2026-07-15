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

<svg class="phone-art" viewBox="0 0 260 520" fill="none" aria-label="iPhone showing TrueLine's Shot Result screen: top-down lane view with the tracked path and its metric tiles">
  <rect x="6" y="6" width="248" height="508" rx="42" fill="#1c1c1e" stroke="#3a3a3e" stroke-width="2"/>
  <rect x="16" y="16" width="228" height="488" rx="33" fill="#0e0e10"/>
  <rect x="102" y="26" width="56" height="15" rx="7.5" fill="#000000"/>
  <text x="130" y="60" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="12" font-weight="700" fill="#ececee">Shot Result</text>
  <rect x="43" y="72" width="174" height="246" rx="10" fill="#141416"/>
  <rect x="51" y="92" width="4" height="202" fill="#262628"/>
  <rect x="205" y="92" width="4" height="202" fill="#262628"/>
  <rect x="55" y="92" width="150" height="202" fill="#37373c" stroke="#464b50" stroke-width="1"/>
  <g stroke="#41464b" stroke-width="0.7">
    <line x1="189.2" y1="92" x2="189.2" y2="294"/>
    <line x1="169.5" y1="92" x2="169.5" y2="294"/>
    <line x1="149.7" y1="92" x2="149.7" y2="294"/>
    <line x1="130.0" y1="92" x2="130.0" y2="294"/>
    <line x1="110.3" y1="92" x2="110.3" y2="294"/>
    <line x1="90.5" y1="92" x2="90.5" y2="294"/>
    <line x1="70.8" y1="92" x2="70.8" y2="294"/>
  </g>
  <text x="169.5" y="302.0" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="6" fill="#98989f">10</text>
  <text x="130.0" y="302.0" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="6" fill="#98989f">20</text>
  <text x="90.5" y="302.0" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="6" fill="#98989f">30</text>
  <rect x="55" y="92" width="150" height="0.0" fill="none"/>
  <rect x="55" y="92" width="150" height="0.0" fill="none"/>
  <rect x="55" y="65.4" width="150" height="26.6" fill="#232326"/>
  <rect x="137.9" y="92.0" width="3.9" height="40.4" fill="#40e69e" opacity="0.14"/>
  <line x1="141.1" y1="92.0" x2="141.1" y2="132.4" stroke="#29946b" stroke-width="0.8" stroke-dasharray="3 4"/>
  <line x1="55" y1="294.0" x2="205" y2="294.0" stroke="#29946b" stroke-width="1.6"/>
  <line x1="55" y1="273.8" x2="205" y2="273.8" stroke="#29946b" stroke-width="0.8" stroke-dasharray="4 3"/>
  <line x1="55" y1="92.0" x2="205" y2="92.0" stroke="#29946b" stroke-width="1.4"/>
  <polyline points="189.2,253.6 169.5,249.1 149.7,244.6 130.0,240.1 110.3,244.6 90.5,249.1 70.8,253.6" stroke="#29946b" stroke-width="0.8"/>
  <g fill="#40e69e">
    <path d="M189.2 251.0 L187.0 255.5 L191.4 255.5 Z"/>
    <path d="M169.5 246.5 L167.3 251.0 L171.7 251.0 Z"/>
    <path d="M149.7 242.0 L147.5 246.5 L151.9 246.5 Z"/>
    <path d="M130.0 237.5 L127.8 242.0 L132.2 242.0 Z"/>
    <path d="M110.3 242.0 L108.1 246.5 L112.5 246.5 Z"/>
    <path d="M90.5 246.5 L88.3 251.0 L92.7 251.0 Z"/>
    <path d="M70.8 251.0 L68.6 255.5 L73.0 255.5 Z"/>
  </g>
  <circle cx="130.0" cy="92.0" r="2.6" fill="#40e69e" stroke="#292929" stroke-width="0.7"/>
  <circle cx="152.3" cy="85.0" r="2.6" fill="#40e69e" stroke="#292929" stroke-width="0.7"/>
  <circle cx="107.7" cy="85.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="174.5" cy="78.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="130.0" cy="78.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="85.5" cy="78.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="196.8" cy="71.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="152.3" cy="71.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="107.7" cy="71.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <circle cx="63.2" cy="71.0" r="2.6" fill="#dbdbde" stroke="#292929" stroke-width="0.7"/>
  <path d="M137.9 294.0 L141.0 288.9 L144.0 283.9 L146.9 278.9 L149.6 273.8 L152.3 268.8 L154.8 263.7 L157.2 258.6 L159.5 253.6 L161.7 248.6 L163.8 243.5 L165.8 238.4 L167.7 233.4 L169.4 228.4 L171.1 223.3 L172.6 218.2 L174.0 213.2 L175.3 208.1 L176.5 203.1 L177.5 198.1 L178.5 193.0 L179.3 187.9 L180.1 182.9 L180.7 177.9 L181.2 172.8 L181.6 167.8 L181.9 162.7 L182.0 157.6 L182.1 152.6 L180.4 147.6 L178.4 142.5 L176.0 137.4 L173.4 132.4 L170.4 127.4 L167.1 122.3 L163.5 117.2 L159.5 112.2 L155.3 107.1 L150.7 102.1 L145.9 97.1 L140.7 92.0" stroke="#40e69e" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M151.7 241.7 L148.5 247.7 L154.9 247.7 Z" fill="#40e69e"/>
  <rect x="156.7" y="239.6" width="22" height="11" rx="5.5" fill="#000000" opacity="0.6"/>
  <text x="167.7" y="247.5" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="7" font-weight="600" fill="#ffffff">14.5</text>
  <circle cx="182.1" cy="152.6" r="3.2" fill="#40e69e"/>
  <rect x="187.1" y="147.1" width="19" height="11" rx="5.5" fill="#000000" opacity="0.6"/>
  <text x="196.6" y="155.0" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="7" font-weight="600" fill="#ffffff">6.8</text>
  <g font-family="-apple-system, Helvetica, sans-serif">
    <rect x="28" y="326" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="338" font-size="7" fill="#98989f">Speed</text>
    <text x="37" y="353" font-size="13" font-weight="700" fill="#ececee">17.2 <tspan font-size="7" font-weight="400" fill="#98989f">mph</tspan></text>
    <rect x="133" y="326" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="142" y="338" font-size="7" fill="#98989f">Board at Arrows</text>
    <text x="142" y="353" font-size="13" font-weight="700" fill="#ececee">14.5 <tspan font-size="7" font-weight="400" fill="#98989f">board</tspan></text>
    <rect x="28" y="371" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="383" font-size="7" fill="#98989f">Launch Angle</text>
    <text x="37" y="398" font-size="13" font-weight="700" fill="#ececee">6.2 <tspan font-size="7" font-weight="400" fill="#98989f">°</tspan></text>
    <rect x="133" y="371" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="142" y="383" font-size="7" fill="#98989f">Entry Board</text>
    <text x="142" y="398" font-size="13" font-weight="700" fill="#40e69e">17.3 <tspan font-size="7" font-weight="400" fill="#98989f">board</tspan></text>
    <text x="142" y="407" font-size="6" fill="#40e69e" opacity="0.8">target 17–18</text>
    <rect x="28" y="416" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="428" font-size="7" fill="#98989f">Entry Angle</text>
    <text x="37" y="443" font-size="13" font-weight="700" fill="#40e69e">4.8 <tspan font-size="7" font-weight="400" fill="#98989f">°</tspan></text>
    <text x="37" y="452" font-size="6" fill="#40e69e" opacity="0.8">target 4–6</text>
    <rect x="133" y="416" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="142" y="428" font-size="7" fill="#98989f">Breakpoint</text>
    <text x="142" y="443" font-size="13" font-weight="700" fill="#ececee">6.8 <tspan font-size="7" font-weight="400" fill="#98989f">board</tspan></text>
    <rect x="28" y="461" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="37" y="473" font-size="7" fill="#98989f">Breakpoint Distance</text>
    <text x="37" y="488" font-size="13" font-weight="700" fill="#ececee">42 <tspan font-size="7" font-weight="400" fill="#98989f">ft</tspan></text>
    <rect x="133" y="461" width="100" height="40" rx="9" fill="#1d1d21"/>
    <text x="142" y="473" font-size="7" fill="#98989f">Hook</text>
    <text x="142" y="488" font-size="13" font-weight="700" fill="#ececee">10.5 <tspan font-size="7" font-weight="400" fill="#98989f">boards</tspan></text>
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
