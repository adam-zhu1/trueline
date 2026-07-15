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
.cta-note { font-size: 0.85rem; color: var(--muted); margin-top: 0.75rem !important; }
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

<svg class="phone-art" viewBox="0 0 260 520" fill="none" aria-label="iPhone showing TrueLine's lane view: a tracked throw hooking into the pocket, with speed, arrows, breakpoint, and entry-angle stats">
  <!-- phone body; the app is always dark, so the screen keeps its own colors -->
  <rect x="6" y="6" width="248" height="508" rx="42" fill="#1c1c1e" stroke="#3a3a3e" stroke-width="2"/>
  <rect x="16" y="16" width="228" height="488" rx="33" fill="#0e0e10"/>
  <rect x="102" y="28" width="56" height="17" rx="8.5" fill="#000000"/>
  <!-- header -->
  <text x="130" y="70" text-anchor="middle" font-family="-apple-system, Helvetica, sans-serif" font-size="10" letter-spacing="1.5" fill="#98989f">SHOT 7 · LANE 12</text>
  <!-- lane view -->
  <rect x="95" y="84" width="70" height="212" fill="#17171a"/>
  <g stroke="#26262a" stroke-width="0.7">
    <line x1="105" y1="84" x2="105" y2="296"/>
    <line x1="115" y1="84" x2="115" y2="296"/>
    <line x1="125" y1="84" x2="125" y2="296"/>
    <line x1="135" y1="84" x2="135" y2="296"/>
    <line x1="145" y1="84" x2="145" y2="296"/>
    <line x1="155" y1="84" x2="155" y2="296"/>
  </g>
  <!-- gutters -->
  <line x1="91" y1="84" x2="91" y2="296" stroke="#3a3a3e" stroke-width="2"/>
  <line x1="169" y1="84" x2="169" y2="296" stroke="#3a3a3e" stroke-width="2"/>
  <!-- pins: 4-3-2-1, head pin nearest -->
  <g fill="#e8e8ec">
    <circle cx="104" cy="92" r="3.2"/><circle cx="121.3" cy="92" r="3.2"/><circle cx="138.7" cy="92" r="3.2"/><circle cx="156" cy="92" r="3.2"/>
    <circle cx="112.7" cy="100" r="3.2"/><circle cx="130" cy="100" r="3.2"/><circle cx="147.3" cy="100" r="3.2"/>
    <circle cx="121.3" cy="108" r="3.2"/><circle cx="138.7" cy="108" r="3.2"/>
    <circle cx="130" cy="116" r="3.2"/>
  </g>
  <!-- arrows, center farthest down-lane -->
  <g stroke="#4a4a50" stroke-width="1.5" stroke-linecap="round">
    <path d="M126 232 l4 -7 l4 7"/>
    <path d="M112 238 l4 -7 l4 7"/>
    <path d="M140 238 l4 -7 l4 7"/>
    <path d="M98 244 l4 -7 l4 7"/>
    <path d="M154 244 l4 -7 l4 7"/>
  </g>
  <!-- approach dots + foul line -->
  <g fill="#4a4a50">
    <circle cx="110" cy="282" r="1.5"/><circle cx="120" cy="282" r="1.5"/><circle cx="130" cy="282" r="1.5"/><circle cx="140" cy="282" r="1.5"/><circle cx="150" cy="282" r="1.5"/>
  </g>
  <line x1="91" y1="296" x2="169" y2="296" stroke="#4a4a50" stroke-width="1.5"/>
  <!-- tracked path: launch, drift toward the gutter, breakpoint, hook into the 1–3 pocket -->
  <path d="M136 296 C 146 262 156 210 157 168 C 157.5 148 145 128 134.8 114.5" stroke="#45e6a0" stroke-width="2.5" stroke-linecap="round"/>
  <circle cx="157" cy="168" r="4.5" stroke="#45e6a0" stroke-width="2"/>
  <circle cx="134.8" cy="113.5" r="3" fill="#45e6a0"/>
  <!-- stat tiles -->
  <g font-family="-apple-system, Helvetica, sans-serif">
    <rect x="28" y="316" width="98" height="60" rx="12" fill="#1a1a1e" stroke="#26262a"/>
    <text x="40" y="344" font-size="19" font-weight="700" fill="#ececee">17.2</text>
    <text x="40" y="362" font-size="8" letter-spacing="1" fill="#98989f">MPH · SPEED</text>
    <rect x="134" y="316" width="98" height="60" rx="12" fill="#1a1a1e" stroke="#26262a"/>
    <text x="146" y="344" font-size="19" font-weight="700" fill="#ececee">10.4</text>
    <text x="146" y="362" font-size="8" letter-spacing="1" fill="#98989f">ARROW BOARD</text>
    <rect x="28" y="384" width="98" height="60" rx="12" fill="#1a1a1e" stroke="#26262a"/>
    <text x="40" y="412" font-size="19" font-weight="700" fill="#ececee">6 <tspan font-size="11" font-weight="600" fill="#98989f">@ 42 FT</tspan></text>
    <text x="40" y="430" font-size="8" letter-spacing="1" fill="#98989f">BREAKPOINT</text>
    <rect x="134" y="384" width="98" height="60" rx="12" fill="#1a1a1e" stroke="#26262a"/>
    <text x="146" y="412" font-size="19" font-weight="700" fill="#ececee">5.2°</text>
    <text x="146" y="430" font-size="8" letter-spacing="1" fill="#98989f">ENTRY ANGLE</text>
    <!-- pocket pill -->
    <rect x="93" y="458" width="74" height="22" rx="11" fill="#45e6a0"/>
    <text x="130" y="472.5" text-anchor="middle" font-size="9.5" font-weight="700" letter-spacing="1" fill="#0e0e10">POCKET ✓</text>
  </g>
</svg>
<p class="art-caption">One throw in TrueLine — tracked, measured, scored.</p>

<div class="cta-block">
<p><strong>TrueLine is coming to the App Store.</strong></p>
<a class="cta-button" href="mailto:adamzhu@andrew.cmu.edu?subject=Notify%20me%20%E2%80%94%20TrueLine&body=Put%20me%20on%20the%20launch%20list.%0A%0A(Optional)%20I%20bowl%20league%20at%3A%20">Get notified at launch</a>
<p class="cta-note">One email when it ships — nothing else. Want to try it early? Say so and you're on the TestFlight beta list.</p>
</div>

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
