---
title: Support
---

# Support

Need help with TrueLine? Send a message below. Include what happened, which iPhone you have, and what the screen showed if it was about a specific throw. You'll usually hear back within a couple of days.

<style>
.contact-form { display: grid; gap: 0.75rem; max-width: 26rem; margin: 1.5rem 0 2rem; }
.contact-input, .contact-msg {
  font: inherit;
  font-size: 16px; /* ≥16px stops iOS Safari zooming the page on focus */
  color: var(--ink);
  background: var(--bg);
  border: 1px solid var(--rule);
  border-radius: 12px;
  padding: 0.7rem 1rem;
  width: 100%;
}
.contact-msg { min-height: 7.5rem; resize: vertical; }
.contact-input:focus, .contact-msg:focus { outline: 2px solid var(--accent); outline-offset: 1px; }
.contact-send {
  justify-self: start;
  background: var(--accent);
  color: var(--bg);
  font: inherit;
  font-size: 16px;
  font-weight: 600;
  border: 0;
  border-radius: 999px;
  padding: 0.7rem 1.6rem;
  cursor: pointer;
}
.contact-send:hover { opacity: 0.9; }
.contact-send:disabled { opacity: 0.6; }
.contact-done { color: var(--accent); font-weight: 600; }
.contact-note { font-size: 0.85rem; color: var(--muted); margin: 0; }
</style>

<form id="contact-form" class="contact-form" action="https://formspree.io/f/mlgqdanz" method="POST">
  <input type="hidden" name="_subject" value="TrueLine support message">
  <input type="hidden" name="type" value="support">
  <input class="contact-input" type="email" name="email" required placeholder="you@example.com" autocomplete="email" aria-label="Your email, for the reply">
  <textarea class="contact-msg" name="message" required placeholder="What happened? Include which iPhone you have." aria-label="Your message"></textarea>
  <button class="contact-send" type="submit">Send</button>
  <p class="contact-note" id="contact-fail" hidden>That didn't send. Please try again in a minute.</p>
</form>

<script>
(function () {
  var form = document.getElementById("contact-form");
  if (!form) return;
  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var btn = form.querySelector("button");
    btn.disabled = true;
    btn.textContent = "Sending…";
    fetch(form.action, {
      method: "POST",
      body: new FormData(form),
      headers: { Accept: "application/json" },
    }).then(function (r) {
      if (!r.ok) { throw new Error("bad status"); }
      form.innerHTML = '<p class="contact-done">✓ Sent. You’ll usually hear back within a couple of days.</p>';
    }).catch(function () {
      btn.disabled = false;
      btn.textContent = "Send";
      document.getElementById("contact-fail").hidden = false;
    });
  });
})();
</script>

## Quick answers

**Where do I put the phone?**
Prop it on the ball return or a table behind the approach, looking straight down your lane, with the whole lane in frame, from the foul line to the pins. Don't move it between throws.

**The numbers look wrong (impossible speed, board 30+ at the arrows).**
This almost always means the calibration no longer matches the camera, usually because the phone moved after you set the lane corners. Recalibrate on your next throw: drag the four corners so they sit exactly on the lane edges at the foul line and the pin deck.

**The ball wasn't tracked.**
Make sure the full throw is visible in the clip, the lane corners are set correctly, and the recording starts before the ball leaves your hand (speed needs the ball tracked through the front of the lane).

**Board numbers seem mirrored.**
Check your bowling hand in Settings. Boards are counted from your side of the lane, so the wrong hand mirrors every number.

**How do I free up storage?**
Settings shows how much space shot replays use. You can turn off "Save video with each shot" or delete all replay videos. Your metrics and lane views are always kept.

**Is my footage uploaded anywhere?**
No. Everything runs on your phone; TrueLine makes no network connections. See the [Privacy Policy](privacy.md).
