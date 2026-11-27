/* ---------- 中英双语 ----------
 * HTML 源码里写中文（无 JS 和搜索引擎看到的就是中文），这里只放英文词典。
 * 标了 data-i18n="key" 的元素整体替换 innerHTML；
 * data-i18n-attr="alt:key;aria-label:key2" 替换属性。
 * 启动时从 DOM 记下中文原文，切回中文时直接还原，不需要中文词典。
 */
(() => {
  const STORAGE_KEY = "voiceinput-lang";

  const EN = {
    "meta.title": "VoiceInput — Hold ⌥ and talk to type",
    "meta.desc": "VoiceInput is a native macOS menu bar voice input tool. Hold Right Option to speak, release to type into any editor, terminal or chat box. Free, no API key, on-device recognition by default, plus clipboard history.",
    "meta.ogDesc": "Native macOS voice input. Free, no API key, your voice stays on your Mac.",

    "nav.how": "How It Works",
    "nav.features": "Features",
    "nav.clipboard": "Clipboard",
    "nav.gallery": "Interface",
    "nav.install": "Install",
    "nav.faq": "FAQ",
    "nav.donate": "Donate",
    "nav.download": "Free Download",
    "nav.langLabel": "Switch to Chinese",

    "hero.pill": "v1.3.0 · Native macOS · Apple Silicon &amp; Intel",
    "hero.title": 'Hold <kbd class="kbd-hero">⌥</kbd>,<br />\n<span class="gradient-text">talk to type</span>',
    "hero.lead": "VoiceInput lives in your menu bar. In any editor, terminal or chat box, hold Right Option and speak — let go, and the text appears at your cursor.",
    "hero.download": "Download for macOS",
    "hero.github": "Source on GitHub",
    "hero.meta1": '<span class="check">✓</span>Free, no API key',
    "hero.meta2": '<span class="check">✓</span>On-device by default',
    "hero.meta3": '<span class="check">✓</span>Works in any app',
    "hero.iconAlt": "VoiceInput icon",

    "demo.mbTerminal": "Terminal",
    "demo.mbEdit": "Edit",
    "demo.mbView": "View",
    "demo.mbWindow": "Window",
    "demo.messages": "Messages",
    "demo.bubbleIn": "How's tonight's release going?",
    "demo.keyHint": "Hold Right Option to speak",
    "demo.caption": "↑ Live demo right on this page: hold, speak, release — the text goes straight into the active window",

    "hud.listening": "Listening…",
    "hud.release": "Release Right Option to finish",
    "hud.recognizing": "Recognizing…",
    "hud.inserted": "Inserted",
    "hud.missed": "Didn't catch that",
    "hud.retry": "Hold Right Option and try again",
    "hud.sample": "Shipping the new release at 8 tonight",
    "hud.dragPreview": "Drag the slider to preview",

    "stats.apiKey": "API keys needed",
    "stats.currency": "$",
    "stats.cost": "Cost to use",
    "stats.maxRec": "Max recording length",
    "stats.arch": "Architectures (arm64 · x86_64)",

    "how.title": "Three steps, nothing to learn",
    "how.sub": "No window switching, no buttons. Keep your hands on the keyboard and turn thoughts into text.",
    "how.s1t": "Put your cursor in a text field",
    "how.s1p": "Terminal, code editor, browser, chat app… anywhere you can type.",
    "how.s2t": "Hold Right Option and speak",
    "how.s2p": "“Listening…” appears at the bottom of the screen, with live results as you talk.",
    "how.s3demo": 'Refactor this code for me<span class="blink-caret"></span>',
    "how.s3t": "Let go, and it's typed",
    "how.s3p": "The text lands right at your cursor. Press Return to send.",

    "feat.title": "Small, but every detail thought through",
    "feat.sub": "A native menu bar app written in pure Swift. No Node, no Python, no runtime dependencies.",
    "feat.aT": "Your voice stays on your Mac",
    "feat.aP": "Apple's on-device recognition is used first. Once the dictation language pack is downloaded, it works fully offline and audio is never sent to any server.",
    "feat.pvMic": "Mic",
    "feat.pvLocal": "On-device",
    "feat.pvText": "Text",
    "feat.pvCloud": "Cloud",
    "feat.bT": "If you can type there, you can talk there",
    "feat.bP": "System-level input. No plugins needed.",
    "feat.cT": "No accidental triggers",
    "feat.cP": "Holds shorter than 0.35s are ignored. Press another key while holding ⌥ (say ⌥+arrow) and that recording is canceled — your shortcut works as usual.",
    "feat.dT": "Two ways to insert",
    "feat.dP": "By default it types the text in like a keyboard and leaves your clipboard alone. Switch to “Paste” and the text is also copied to the clipboard, ready to paste again.",
    "feat.eT": "Overlay opacity, live as you drag",
    "feat.eP": "Drag the slider right in the menu and see the result instantly, no restart. Try it:",
    "feat.fT": "Mixed Chinese &amp; English · Custom vocabulary",
    "feat.fP": "Tuned for Mandarin, with English words mixed in. Add the project and framework names you use to <code>contextualStrings</code> for noticeably better accuracy. Speak another language? Change <code>locale</code> in the config.",
    "feat.fYours": "+ your words",
    "feat.gT": "And the rest",
    "feat.g1": "Press <kbd>Esc</kbd> while recording to cancel",
    "feat.g2": "Launches at login, one click to turn off",
    "feat.g3": "Start / stop sounds can be turned off",
    "feat.g4": "In Paste mode, the text also stays on your clipboard",

    "app.terminal": "Terminal",
    "app.wechat": "WeChat",
    "app.lark": "Lark",
    "app.notes": "Notes",
    "app.mail": "Mail",

    "clip.pill": "NEW · Just added",
    "clip.title": 'Never lose<br /><span class="gradient-text">anything you copied</span>',
    "clip.lead": "VoiceInput quietly remembers the text and images you copied recently. Need something from earlier? One shortcut brings it back, ready to paste.",
    "clip.p1": "<b>Press <kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd> to open history</b>A list pops up next to your pointer. Pick with the arrow keys and Return, or just press 1–9",
    "clip.p2": "<b>Images too</b>Screenshots copied to the clipboard and images copied from web pages or chats show up as thumbnails",
    "clip.p3": "<b>You decide how many</b>Choose 10, 20, 50 or 100 items in the menu, 20 by default",
    "clip.p4": "<b>Memory only</b>Cleared when you quit, never written to disk. Passwords copied from password managers are never recorded",
    "clip.count": "6 items",
    "clip.r1": "Shipping the new release at 8 tonight, check the config 10 minutes before going live",
    "clip.t1": "just now",
    "clip.r2": "Image 2880×1800",
    "clip.t2": "2 min ago",
    "clip.t3": "5 min ago",
    "clip.r4": 'git commit -m "Fix login page layout in dark mode"',
    "clip.t4": "12 min ago",
    "clip.r5": "Image 1080×1440",
    "clip.t5": "1 h ago",
    "clip.r6": "Friday 3 PM, big meeting room on the 3rd floor",
    "clip.t6": "2 h ago",
    "clip.kSelect": "<kbd>↑↓</kbd>Select",
    "clip.kPaste": "<kbd>↩</kbd>Paste",
    "clip.kQuick": "<kbd>1-9</kbd>Quick paste",
    "clip.kClose": "<kbd>esc</kbd>Close",

    // 菜单模型与 App 英文菜单文案保持一致
    "menu.ready": "Ready · Hold Right Option to speak",
    "menu.last": "Last: Refactor this code for me",
    "menu.insert": "Insert Method<span>›</span>",
    "menu.simulate": "Simulate Typing",
    "menu.paste": "Paste",
    "menu.onDevice": "<i>✓</i>On-Device Recognition",
    "menu.sound": "<i>✓</i>Play Feedback Sound",
    "menu.hud": "<i>✓</i>Show Floating Hints",
    "menu.opacity": "Overlay Opacity",
    "menu.opacityRow": 'Overlay Opacity <span class="mm-slider"><b></b></span><small>45%</small>',
    "menu.clipboard": "Clipboard History",
    "menu.clipboardSub": "Clipboard History<span>›</span>",
    "menu.language": "Language<span>›</span>",
    "menu.openConfig": "Open Config File",
    "menu.reload": "Reload Config",
    "menu.login": "<i>✓</i>Launch at Login",
    "menu.quit": 'Quit VoiceInput<span class="sc">⌘Q</span>',

    "gal.title": "Quiet in your menu bar, there when you need it",
    "gal.sub": "Every setting lives behind the menu bar icon, and the floating hint uses a color for each stage.",
    "gal.time": "Fri 10:24",
    "gal.capMenu": "<b>Menu bar</b>Recognition, sounds and opacity, all in one place",
    "gal.capHud": "<b>Floating hints</b>Listening · Recognizing · Done · Error — the state at a glance",
    "gal.capConfig": "<b>Config file</b>Plain JSON. Edit it, then choose “Reload Config” in the menu",

    "inst.title": "Set up in a minute",
    "inst.sub": "For Macs with Apple Silicon or Intel chips.",
    "inst.dlHint": "Open it and drag VoiceInput into your Applications folder",
    "inst.allReleases": "All releases →",
    "inst.noteT": "macOS can't verify the developer on first launch?",
    "inst.noteP": "This is the usual macOS warning for apps not registered with Apple. Do this once and you won't see it again:",
    "inst.n1": "Click “Done” (or “OK”) to close the dialog",
    "inst.n2": "Open System Settings → Privacy &amp; Security in the sidebar",
    "inst.n3": "Scroll down to “VoiceInput was blocked…” and click “Open Anyway”",
    "inst.n4": "Enter your login password to confirm, and the app opens normally",
    "inst.alt": "Alternative (for Terminal users)",
    "inst.copy": "Copy",
    "inst.pMic": "<b>Allow Microphone</b><span>For recording</span>",
    "inst.pSpeech": "<b>Allow Speech Recognition</b><span>Turns audio into text</span>",
    "inst.pAx": "<b>Allow Accessibility</b><span>Listens for Right Option and types into the active window</span>",
    "inst.pDict": "<b>Turn on Dictation</b><span>System Settings → Keyboard → Dictation: turn it on and add “Chinese (Mandarin)”, the default recognition language. Speech recognition needs it, and once the language pack is downloaded it works fully offline</span>",

    "faq.q1": "Nothing happens when I hold Right Option?",
    "faq.a1": "<p>Usually Accessibility access isn't turned on, or the app hasn't been restarted since:</p><ol><li>Open System Settings → Privacy &amp; Security → Accessibility and make sure VoiceInput is switched on</li><li>Click the mic icon in the top-right of the screen → Quit VoiceInput, then open it again</li></ol><p>Make sure you press the Option (⌥) key on the <b>right side</b> of the keyboard; the left one doesn't count. While recording, the mic icon in the menu bar turns red.</p>",
    "faq.q2": "Seeing “Siri and Dictation are disabled” or “Turn on Dictation first”?",
    "faq.a2": "<p>That means Dictation is off on your Mac. Apple's speech recognition only works once it's on:</p><ol><li>Open System Settings → Keyboard</li><li>Find Dictation, turn it on and add “Chinese (Mandarin)” under Languages</li><li>Go back to any text field and hold Right Option to try again</li></ol><p>When this message appears, VoiceInput opens the Keyboard settings for you.</p>",
    "faq.q3": "I see “Listening…”, but no text appears after I let go?",
    "faq.a3": "<p>First make sure the cursor is somewhere you can type (like the blinking line in a text field).</p><p>If it still doesn't work, check that Accessibility access is on — VoiceInput needs it to type the text for you. A few apps don't accept simulated typing; try switching Insert Method to “Paste” in the menu.</p>",
    "faq.q4": "Does it need the internet? Is my voice uploaded?",
    "faq.a4": "<p>It can work fully offline. Download the speech language pack on your Mac once, and recognition happens entirely on your computer — your voice never leaves this Mac:</p><ol><li>Open System Settings → Keyboard</li><li>Find Dictation, turn it on and add “Chinese (Mandarin)” under Languages</li><li>Wait for the download to finish</li></ol><p>Without the language pack, VoiceInput falls back to Apple's online recognition. It still works, but needs the internet and your audio is sent to Apple for processing.</p>",
    "faq.q5": "The recognized text isn't accurate. What can I do?",
    "faq.a5": "<p>A few tips:</p><ol><li>Stay close to the mic, speak at a normal pace and clearly</li><li>A few English words in a Chinese sentence are fine, but switching back and forth a lot lowers accuracy</li><li>Download the language pack as described above for more stable results</li></ol><p><b>Names, companies or jargon it keeps getting wrong? You can “teach” it:</b></p><ol><li>Click the mic icon in the top-right of the screen → “Open Config File”</li><li>Find the <code>contextualStrings</code> line and add your words inside the brackets, for example:<br /><code>\"contextualStrings\": [\"Kubernetes\", \"SwiftUI\", \"Acme\"]</code></li><li>Save the file, then click “Reload Config” in the menu; it takes effect right away</li></ol><p class=\"faq-note\">Note: wrap each word in straight double quotes <code>\"</code> and separate words with ASCII commas <code>,</code>. Full-width (Chinese) quotes or commas won't work.</p>",
    "faq.q6": "My clipboard changed after using it?",
    "faq.a6": "<p>The default Insert Method is “Simulate Typing”, which types the text in like a keyboard and never touches your clipboard.</p><p>If you switched Insert Method to “Paste” in the menu, the recognized text is also copied to the clipboard so you can paste it again elsewhere with ⌘V. To stop that, click the mic icon in the top-right of the screen → “Insert Method” → choose “Simulate Typing”.</p>",
    "faq.q7": "⇧⌘V no longer does “Paste and Match Style”?",
    "faq.a7": "<p>With Clipboard History on, ⇧⌘V opens the history list, so “Paste and Match Style” on the same shortcut in Chrome, Slack and other apps is temporarily unavailable.</p><p>If you prefer the original behavior, click the mic icon in the top-right of the screen → “Clipboard History” → uncheck “Enable Clipboard History”, and ⇧⌘V goes back to normal.</p>",
    "faq.q8": "Is clipboard history saved or uploaded?",
    "faq.a8": "<p>No. History lives only in memory: it's never written to disk or sent anywhere, and it's cleared when you quit VoiceInput or restart your Mac.</p><p>Passwords copied from password managers like 1Password are skipped automatically. To clear it right away, choose “Clipboard History” → “Clear History” in the menu.</p>",
    "faq.q9": "Does it launch every time I start my Mac? How do I turn that off?",
    "faq.a9": "<p>The first time you open it from Applications, it sets itself to launch at login so it's always ready.</p><p>If you'd rather not, click the mic icon in the top-right of the screen and click “Launch at Login” in the menu. Once the checkmark is gone, it's off.</p>",
    "faq.q10": "How do I update to a new version?",
    "faq.a10": "<p>VoiceInput checks for new versions automatically. When one is available, click the mic icon in the top-right of the screen and “Update to v…” appears at the top of the menu. One click downloads, installs and reopens it — no dragging needed.</p><p>After updating, remember to switch VoiceInput back on in System Settings → Privacy &amp; Security → Accessibility. You can also check manually any time with “Check for Updates…” in the menu.</p>",
    "faq.q11": "Does it cost anything? Do I need an account?",
    "faq.a11": "<p>It's completely free. No sign-up, no keys to enter. Speech recognition uses what's built into macOS.</p>",

    "don.title": "Enjoying it? Buy the author a coffee",
    "don.sub": "VoiceInput is free forever. Tips are completely optional, any amount — your support helps make it better.",
    "don.wechat": "WeChat Pay",
    "don.alipay": "Alipay",
    "don.wechatAlt": "WeChat Pay QR code",
    "don.alipayAlt": "Alipay QR code",
    "don.wechatScan": "Scan with WeChat",
    "don.alipayScan": "Scan with Alipay",
    "don.payee": "Payee: Eoccc (**凯)",
    "don.tip": "On a phone, long-press the QR code to save it, then open Scan in WeChat or Alipay and pick it from your photos.",

    "final.title": 'Keep your keys for shortcuts, <span class="gradient-text">let your voice do the typing</span>',
    "final.cta": "Download VoiceInput Free",
    "footer.releases": "Releases",
  };

  // 跟 App 一致：系统首选语言是中文就用中文，其余一律英文；用户手动选过则以手动为准
  function detectLang() {
    let saved = null;
    try { saved = localStorage.getItem(STORAGE_KEY); } catch {}
    if (saved === "zh" || saved === "en") return saved;
    const preferred = (navigator.languages && navigator.languages[0]) || navigator.language || "";
    return preferred.toLowerCase().startsWith("zh") ? "zh" : "en";
  }

  const parseAttrSpec = (spec) =>
    spec.split(";").map((pair) => pair.split(":").map((x) => x.trim())).filter(([a, k]) => a && k);

  // 记下中文原文，切回中文时还原
  const zhHTML = new Map();
  const zhAttr = new Map();
  document.querySelectorAll("[data-i18n]").forEach((el) => zhHTML.set(el, el.innerHTML));
  document.querySelectorAll("[data-i18n-attr]").forEach((el) => {
    const saved = {};
    for (const [attr] of parseAttrSpec(el.dataset.i18nAttr)) saved[attr] = el.getAttribute(attr);
    zhAttr.set(el, saved);
  });

  let lang = "zh";
  const listeners = [];

  function apply(next) {
    lang = next;
    const en = lang === "en";
    document.documentElement.lang = en ? "en" : "zh-CN";
    zhHTML.forEach((zh, el) => {
      const html = en ? EN[el.dataset.i18n] ?? zh : zh;
      if (el.innerHTML !== html) el.innerHTML = html;
    });
    zhAttr.forEach((saved, el) => {
      for (const [attr, key] of parseAttrSpec(el.dataset.i18nAttr)) {
        el.setAttribute(attr, en ? EN[key] ?? saved[attr] : saved[attr]);
      }
    });
    // <title> 已由 data-i18n 更新，这里同步 document.title 以防浏览器标签不刷新
    document.title = document.querySelector("title").textContent;
    listeners.forEach((fn) => fn(lang));
  }

  function setLang(next) {
    try { localStorage.setItem(STORAGE_KEY, next); } catch {}
    apply(next);
  }

  window.I18N = {
    get lang() { return lang; },
    // 脚本里动态生成的文案用这个按当前语言二选一
    t: (zh, en) => (lang === "en" ? en : zh),
    onChange: (fn) => listeners.push(fn),
    setLang,
    keys: EN,
  };

  apply(detectLang());

  const toggle = document.getElementById("langSwitch");
  if (toggle) toggle.addEventListener("click", () => setLang(lang === "en" ? "zh" : "en"));
})();
