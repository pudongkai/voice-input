/*
 * 站点中英双语。
 * 页面 HTML 本身就是中文，启动时把带 data-i18n / data-i18n-attr 的元素原文记下来作为中文版本，
 * 所以静态文案只需要在 EN 里写英文；main.js 动态生成的文案两种语言都放在 DYNAMIC 里。
 * 当前语言由 <head> 里的内联脚本决定并写到 <html lang>，这里只读取它。
 */
(() => {
  const STORE_KEY = "lang";

  // 静态文案（英文）。值会以 innerHTML 写入，可包含页面原有的标记，均为本文件内的固定字符串。
  const EN = {
    "meta.title": "VoiceInput — Hold ⌥ and talk to type",
    "meta.desc": "VoiceInput is a native macOS menu bar voice input app. Hold Right Option to speak, release to type into any editor, terminal or chat box. Free, no API key, on-device recognition by default, plus clipboard history.",
    "meta.ogDesc": "Native voice input for macOS. Free, no API key, and your voice stays on your Mac.",

    "nav.how": "How it works",
    "nav.features": "Features",
    "nav.clipboard": "Clipboard",
    "nav.gallery": "Interface",
    "nav.install": "Install",
    "nav.faq": "FAQ",
    "nav.donate": "Donate",
    "nav.download": "Free Download",

    "hero.pill": "v1.3.0 · Native macOS · Apple Silicon &amp; Intel",
    "hero.title": 'Hold <kbd class="kbd-hero">⌥</kbd>,<br />\n        <span class="gradient-text">talk to type</span>',
    "hero.lead": "VoiceInput lives in your menu bar. In any editor, terminal or chat box, hold Right Option and speak — release, and the text appears at your cursor.",
    "hero.download": "Download for macOS",
    "hero.source": "Source on GitHub",
    "hero.meta1": "Free, no API key",
    "hero.meta2": "On-device recognition by default",
    "hero.meta3": "Works in any app",
    "hero.iconAlt": "VoiceInput icon",

    "demo.mbTerminal": "Terminal",
    "demo.mbEdit": "Edit",
    "demo.mbView": "View",
    "demo.mbWindow": "Window",
    "demo.time": "Fri 10:24",
    "demo.messages": "Messages",
    "demo.bubbleIn": "How's tonight's release going?",
    "demo.caption": "↑ Live demo: hold, speak, release — the text goes straight into the active window",

    "stats.apiKey": "API keys needed",
    "stats.currency": "$",
    "stats.cost": "Cost to use",
    "stats.maxRec": "Max per recording",
    "stats.arch": "Architectures (arm64 · x86_64)",

    "how.title": "Three steps, nothing to learn",
    "how.desc": "No switching windows, no clicking buttons. Keep your hands on the keyboard and turn thoughts into text.",
    "how.s1": "Put your cursor in a text field",
    "how.s1d": "Terminal, code editor, browser, chat app… anywhere you can type.",
    "how.s2": "Hold Right Option and speak",
    "how.s2d": "A “Listening…” HUD appears at the bottom of the screen and shows results as you talk.",
    "how.sample": 'Refactor this code for me<span class="blink-caret"></span>',
    "how.s3": "Release, and it's typed",
    "how.s3d": "The text lands right at your cursor. Hit Return to send.",

    "feat.title": "Small, but every detail is thought through",
    "feat.desc": "A native menu bar app written in pure Swift — no Node, Python or any other runtime.",
    "feat.privacy": "Your voice stays on your Mac",
    "feat.privacyD": "Uses Apple's on-device recognition by default. Once the dictation language pack is downloaded, it works fully offline and no audio is sent to any server.",
    "feat.pvMic": "Microphone",
    "feat.pvLocal": "On-device",
    "feat.pvText": "Text",
    "feat.pvCloud": "Cloud",
    "feat.anywhere": "If you can type there, you can speak there",
    "feat.anywhereD": "System-wide input, no plugins required.",
    "feat.appTerminal": "Terminal",
    "feat.appWeChat": "WeChat",
    "feat.appFeishu": "Lark",
    "feat.appNotes": "Notes",
    "feat.appMail": "Mail",
    "feat.guard": "No accidental triggers",
    "feat.guardD": "Holds shorter than 0.35 s are ignored. Press another key while holding ⌥ (like ⌥+arrow) and the recording is canceled, so the original shortcut still works.",
    "feat.insert": "Two ways to insert",
    "feat.insertD": "By default it types the text like a keyboard and leaves your clipboard alone. Switch to Paste and the text is also copied to the clipboard, ready to paste again.",
    "feat.segType": "Simulate Typing",
    "feat.segPaste": "Paste",
    "feat.opacity": "HUD opacity, previewed live",
    "feat.opacityD": "Drag the slider right in the menu and see the change instantly, no restart. Try it:",
    "feat.odTitle": "HUD Opacity 45%",
    "feat.odBody": "Drag the slider to preview",
    "feat.odLabel": "HUD Opacity",
    "feat.mixed": "Mixed Chinese &amp; English · Custom terms",
    "feat.mixedD": 'Recognizes Chinese by default and handles English words mixed in. Speak mostly English? Set <code>"locale": "en-US"</code> in the config file. Add project and framework names to <code>contextualStrings</code> for noticeably better accuracy.',
    "feat.tagTerm": "PostgreSQL",
    "feat.tagYours": "+ your words",
    "feat.more": "And more",
    "feat.more1": "Press <kbd>Esc</kbd> to cancel while recording",
    "feat.more2": "Launches at login, off with one click",
    "feat.more3": "Start / stop sounds can be turned off",
    "feat.more4": "In Paste mode, the text also stays on your clipboard",

    "clip.pill": "NEW · Just added",
    "clip.title": 'Copied it once?<br /><span class="gradient-text">It\'s still here.</span>',
    "clip.desc": "VoiceInput quietly remembers the text and images you've copied recently. Need something from earlier? Press a shortcut, pick it, and paste.",
    "clip.p1": "<b>Press <kbd>⇧</kbd><kbd>⌘</kbd><kbd>V</kbd> to open history</b>A list pops up next to your mouse. Pick with the arrow keys and press Return to paste, or just press 1–9",
    "clip.p2": "<b>Screenshots too</b>Screenshots copied to the clipboard and images copied from web pages or chats show up as thumbnails",
    "clip.p3": "<b>You choose how many</b>Keep 10, 20, 50 or 100 items from the menu — 20 by default",
    "clip.p4": "<b>Memory only</b>Cleared when you quit the app and never written to disk. Passwords copied from password managers are never recorded",
    "clip.panelTitle": "Clipboard History",
    "clip.count": "6 items",
    "clip.item1": "Shipping the new version at 8 tonight sharp — remember to check the config 10 minutes before",
    "clip.item2": "Image 2880×1800",
    "clip.item4": 'git commit -m "Fix login page display in dark mode"',
    "clip.item5": "Image 1080×1440",
    "clip.item6": "Friday 3 PM, big meeting room on the 3rd floor",
    "clip.ago0": "just now",
    "clip.ago2m": "2 min ago",
    "clip.ago5m": "5 min ago",
    "clip.ago12m": "12 min ago",
    "clip.ago1h": "1 h ago",
    "clip.ago2h": "2 h ago",
    "clip.footSelect": "<kbd>↑↓</kbd>Select",
    "clip.footPaste": "<kbd>↩</kbd>Paste",
    "clip.footQuick": "<kbd>1-9</kbd>Quick paste",
    "clip.footClose": "<kbd>esc</kbd>Close",

    "gal.title": "Quiet in the menu bar, there when you need it",
    "gal.desc": "Every setting lives in the menu bar icon, and the HUD uses color to show each stage.",
    "gal.mReady": "Ready · Hold Right Option to speak",
    "gal.mLatest": "Latest: Refactor this code for me",
    "gal.mInput": "Input Method<span>›</span>",
    "gal.mOnDevice": "<i>✓</i>On-Device Recognition",
    "gal.mSounds": "<i>✓</i>Play Sounds",
    "gal.mHud": "<i>✓</i>Show Floating HUD",
    "gal.mOpacity": 'HUD Opacity <span class="mm-slider"><b></b></span><small>45%</small>',
    "gal.mClip": "Clipboard History<span>›</span>",
    "gal.mOpenCfg": "Open Config File",
    "gal.mReload": "Reload Config",
    "gal.mLogin": "<i>✓</i>Launch at Login",
    "gal.mQuit": 'Quit VoiceInput<span class="sc">⌘Q</span>',
    "gal.capMenu": "<b>Menu bar</b>Recognition, sounds and opacity, all in one place",
    "gal.sample": "Shipping the new version at 8 tonight",
    "gal.error": "Didn't catch that",
    "gal.errorBody": "Hold Right Option and try again",
    "gal.capStates": "<b>Floating HUD</b>Listening · Recognizing · Done · Error — status at a glance",
    "gal.config": '{\n  <span class="k">"locale"</span>: <span class="s">"en-US"</span>,\n  <span class="k">"insertMethod"</span>: <span class="s">"type"</span>,\n  <span class="k">"onDeviceRecognition"</span>: <span class="b">true</span>,\n  <span class="k">"maxRecordingSeconds"</span>: <span class="n">60</span>,\n  <span class="k">"minHoldSeconds"</span>: <span class="n">0.35</span>,\n  <span class="k">"playFeedbackSound"</span>: <span class="b">true</span>,\n  <span class="k">"hudOpacity"</span>: <span class="n">0.45</span>,\n  <span class="k">"contextualStrings"</span>: [<span class="s">"Kubernetes"</span>, <span class="s">"SwiftUI"</span>]\n}',
    "gal.capConfig": "<b>Config file</b>One JSON file. Edit it, then choose “Reload Config” in the menu",

    "install.title": "Up and running in a minute",
    "install.desc": "For Macs with Apple Silicon or Intel chips.",
    "install.dlHint": "Open it and drag VoiceInput into your Applications folder",
    "install.allReleases": "All releases →",
    "install.noteTitle": "Seeing “developer cannot be verified” on first launch?",
    "install.noteDesc": "This is macOS's standard warning for apps that aren't registered with Apple. Do this once and you won't see it again:",
    "install.note1": "Click “Done” (or “OK”) to close the dialog",
    "install.note2": "Open System Settings and choose Privacy &amp; Security in the sidebar",
    "install.note3": "Scroll down to “VoiceInput was blocked…” and click Open Anyway",
    "install.note4": "Enter your login password to confirm, and the app opens normally",
    "install.adv": "Alternative (for Terminal users)",
    "install.permMic": "Allow Microphone",
    "install.permMicD": "For recording",
    "install.permSpeech": "Allow Speech Recognition",
    "install.permSpeechD": "Turns your recording into text",
    "install.permAx": "Allow Accessibility",
    "install.permAxD": "Watches Right Option and types into the active window",
    "install.permDict": "Turn on Dictation",
    "install.permDictD": "System Settings → Keyboard → Dictation: turn it on and add the language you speak, e.g. Chinese (Mandarin) or English. Speech recognition needs it, and once the language pack downloads it works fully offline",

    "faq.title": "FAQ",
    "faq.q1": "Nothing happens when I hold Right Option?",
    "faq.q1p1": "Usually Accessibility access isn't turned on, or the app hasn't been restarted since:",
    "faq.q1l1": "Open System Settings → Privacy &amp; Security → Accessibility and make sure VoiceInput is switched on",
    "faq.q1l2": "Click the mic icon in the menu bar → Quit VoiceInput, then open it again",
    "faq.q1p2": "Make sure you press the Option (⌥) key on the <b>right side</b> of the keyboard — the left one doesn't count. While recording, the mic icon in the menu bar turns red.",
    "faq.q2": "Seeing “Siri and Dictation are disabled” or “Turn on Dictation first”?",
    "faq.q2p1": "That means Dictation is off on your Mac. Apple's speech recognition needs it turned on:",
    "faq.q2l1": "Open System Settings → Keyboard",
    "faq.q2l2": "Find Dictation, turn it on, and add your language, e.g. Chinese (Mandarin) or English",
    "faq.q2l3": "Go back to any text field and hold Right Option to try again",
    "faq.q2p2": "When this happens, VoiceInput opens the Keyboard settings for you.",
    "faq.q3": "I see “Listening…”, but no text appears after I release?",
    "faq.q3p1": "First, make sure your cursor is somewhere you can type (like the blinking line in a text field).",
    "faq.q3p2": "If it still doesn't work, check that Accessibility access is on — VoiceInput needs it to type the text for you. A few apps don't accept simulated typing; try switching Input Method to Paste in the menu.",
    "faq.q4": "Does it need internet? Is my voice uploaded?",
    "faq.q4p1": "It can run fully offline. Download the speech language pack once and all recognition happens on your Mac — your voice never leaves it:",
    "faq.q4l1": "Open System Settings → Keyboard",
    "faq.q4l2": "Find Dictation, turn it on, and add your language",
    "faq.q4l3": "Wait for the download to finish",
    "faq.q4p2": "Without the language pack, VoiceInput falls back to Apple's online recognition. It still works, but needs internet and sends your audio to Apple for processing.",
    "faq.q5": "The recognized text isn't accurate. What can I do?",
    "faq.q5p1": "A few tips:",
    "faq.q5l1": "Stay close to the mic and speak clearly at a normal pace",
    "faq.q5l2": 'A few words from another language are fine, but switching back and forth a lot lowers accuracy. Mostly speaking English? Set <code>"locale": "en-US"</code> in the config file',
    "faq.q5l3": "Download the language pack as described above for more stable results",
    "faq.q5p2": "<b>Names, company names or jargon it keeps getting wrong? Teach it:</b>",
    "faq.q5l4": "Click the mic icon in the menu bar → Open Config File",
    "faq.q5l5": 'Find the <code>contextualStrings</code> line and add your terms inside the brackets, e.g.:<br /><code>"contextualStrings": ["Jane Doe", "Figma", "OKR"]</code>',
    "faq.q5l6": "Save the file, then click Reload Config in the menu. It takes effect right away",
    "faq.q5note": 'Note: wrap each term in straight double quotes <code>"</code> and separate terms with commas <code>,</code>. Curly quotes or full-width commas won\'t work.',
    "faq.q6": "My clipboard changed after using it?",
    "faq.q6p1": "The default input method is Simulate Typing, which types the text character by character and leaves your clipboard alone.",
    "faq.q6p2": "If you switched Input Method to Paste, the text is also copied to the clipboard so you can press ⌘V to paste it elsewhere. Don't want that? Click the mic icon in the menu bar → Input Method → Simulate Typing.",
    "faq.q7": "⇧⌘V no longer does “Paste and Match Style”?",
    "faq.q7p1": "With clipboard history on, ⇧⌘V opens the history list, so “Paste and Match Style” in apps like Chrome and Slack is unavailable for now.",
    "faq.q7p2": "If you use the original shortcut more, click the mic icon in the menu bar → Clipboard History → uncheck Enable Clipboard History, and ⇧⌘V goes back to normal.",
    "faq.q8": "Is clipboard history saved or uploaded?",
    "faq.q8p1": "No. History lives only in memory — never written to disk or sent anywhere — and is cleared when you quit VoiceInput or restart your Mac.",
    "faq.q8p2": "Passwords copied from password managers like 1Password are skipped automatically. To clear it right away, choose Clipboard History → Clear History in the menu.",
    "faq.q9": "Does it launch at login? How do I turn that off?",
    "faq.q9p1": "The first time you open it from Applications, it sets itself to launch at login so it's always ready.",
    "faq.q9p2": "Don't want that? Click the mic icon in the menu bar, then click Launch at Login so the checkmark disappears.",
    "faq.q10": "How do I update to a new version?",
    "faq.q10p1": "VoiceInput checks for updates automatically. When one is available, click the mic icon in the menu bar and choose “Update to v…” at the top — it downloads, installs and relaunches by itself, no dragging needed.",
    "faq.q10p2": "After updating, turn VoiceInput's switch back on in System Settings → Privacy &amp; Security → Accessibility. You can also choose Check for Updates… in the menu at any time.",
    "faq.q11": "Is it free? Do I need an account?",
    "faq.q11p1": "Completely free. No sign-up, no keys to enter. Speech recognition uses what's built into macOS.",

    "donate.title": "Like it? Buy the author a coffee",
    "donate.desc": "VoiceInput is free forever. Tips are entirely optional and any amount is welcome — your support helps make it better.",
    "donate.wechat": "WeChat",
    "donate.wechatAlt": "WeChat Pay QR code",
    "donate.wechatScan": "Open WeChat and tap Scan",
    "donate.alipay": "Alipay",
    "donate.alipayAlt": "Alipay QR code",
    "donate.alipayScan": "Open Alipay and tap Scan",
    "donate.payee": "Payee: Eoccc (**凯)",
    "donate.tip": "On your phone? Long-press the QR code to save it, then open Scan in WeChat or Alipay and pick it from your photos.",

    "final.title": 'Leave shortcuts to the keyboard, <span class="gradient-text">and the words to your voice</span>',
    "final.download": "Download VoiceInput for Free",
    "footer.releases": "Releases",
  };

  // main.js 运行时生成的文案；部分 key 也被静态元素复用
  const DYNAMIC = {
    "hud.listening": { zh: "正在聆听…", en: "Listening…" },
    "hud.release": { zh: "松开右 Option 结束", en: "Release Right Option to finish" },
    "hud.recognizing": { zh: "识别中…", en: "Recognizing…" },
    "hud.inserted": { zh: "已输入", en: "Inserted" },
    "demo.hint": { zh: "按住右 Option 说话", en: "Hold Right Option to speak" },
    "demo.holding": { zh: "按住右 Option 说话…", en: "Holding Right Option, speak…" },
    "demo.released": { zh: "松开", en: "Released" },
    "demo.text1": { zh: "修复登录页在深色模式下的显示问题", en: "Fix login page display in dark mode" },
    "demo.text2": { zh: "很顺利，今晚八点准时发布新版本", en: "All good, shipping the new version at 8 tonight" },
    "demo.days": {
      zh: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"],
      en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    },
    "opacity.title": { zh: "悬浮窗透明度 {v}%", en: "HUD Opacity {v}%" },
    "copy.label": { zh: "复制", en: "Copy" },
    "copy.done": { zh: "已复制", en: "Copied" },
    "copy.fail": { zh: "复制失败", en: "Copy failed" },
  };

  const root = document.documentElement;
  let lang = root.lang === "en" ? "en" : "zh";
  // 元素 → 中文原文（innerHTML 与各属性值），切回中文时据此还原
  const originals = new Map();

  // data-i18n-attr="alt:key; content:key2"
  const attrPairs = (el) =>
    el.dataset.i18nAttr.split(";").map((p) => p.split(":").map((s) => s.trim())).filter(([a, k]) => a && k);

  function t(key, vars) {
    const entry = DYNAMIC[key];
    let s = entry ? entry[lang] : lang === "en" ? EN[key] : undefined;
    if (typeof s === "string" && vars) s = s.replace(/\{(\w+)\}/g, (m, name) => (name in vars ? vars[name] : m));
    return s ?? key;
  }

  function english(key, fallback) {
    const s = EN[key] ?? DYNAMIC[key]?.en;
    if (s === undefined) console.warn(`[i18n] missing English text: ${key}`);
    return s ?? fallback;
  }

  function snapshot() {
    document.querySelectorAll("[data-i18n]").forEach((el) => originals.set(el, { html: el.innerHTML }));
    document.querySelectorAll("[data-i18n-attr]").forEach((el) => {
      const orig = originals.get(el) || {};
      orig.attrs = Object.fromEntries(attrPairs(el).map(([attr]) => [attr, el.getAttribute(attr)]));
      originals.set(el, orig);
    });
  }

  function translatePage() {
    const en = lang === "en";
    for (const [el, orig] of originals) {
      if (orig.html !== undefined) el.innerHTML = en ? english(el.dataset.i18n, orig.html) : orig.html;
      if (!orig.attrs) continue;
      for (const [attr, key] of attrPairs(el)) {
        el.setAttribute(attr, en ? english(key, orig.attrs[attr]) : orig.attrs[attr]);
      }
    }
  }

  function syncToggle() {
    document.querySelectorAll(".lang-toggle [data-lang]").forEach((btn) => {
      btn.setAttribute("aria-pressed", String(btn.dataset.lang === lang));
    });
  }

  function setLang(next, remember) {
    if (next !== "zh" && next !== "en") return;
    if (remember) {
      try { localStorage.setItem(STORE_KEY, next); } catch { /* 隐私模式下不可写，只影响本次 */ }
    }
    if (next === lang) return;
    lang = next;
    root.lang = lang === "zh" ? "zh-CN" : "en";
    translatePage();
    syncToggle();
    document.dispatchEvent(new CustomEvent("langchange", { detail: { lang } }));
  }

  window.I18N = { get lang() { return lang; }, t, set: setLang };

  snapshot();
  if (lang === "en") translatePage();
  syncToggle();
  document.querySelectorAll(".lang-toggle [data-lang]").forEach((btn) => {
    btn.addEventListener("click", () => setLang(btn.dataset.lang, true));
  });
  root.classList.remove("i18n-pending");
})();
