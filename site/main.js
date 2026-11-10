(() => {
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const $ = (id) => document.getElementById(id);
  const t = (key, vars) => window.I18N.t(key, vars);

  /* ---------- 滚出屏幕或切到其他标签页时暂停动画和演示 ---------- */
  const onScreen = new WeakSet();
  const isActive = (el) => onScreen.has(el) && !document.hidden;
  const waitUntilActive = async (el) => {
    while (!isActive(el)) await sleep(400);
  };

  function initOffscreenPause() {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) onScreen.add(e.target);
        else onScreen.delete(e.target);
        e.target.classList.toggle("offscreen", !e.isIntersecting);
      }
    });
    document.querySelectorAll("[data-anim]").forEach((el) => io.observe(el));
  }

  /* ---------- 滚动进场 + 数字滚动 ---------- */
  function initReveal() {
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        e.target.classList.add("in");
        e.target.querySelectorAll("[data-count]").forEach(countUp);
        if (e.target.hasAttribute("data-count")) countUp(e.target);
        io.unobserve(e.target);
      }
    }, { threshold: 0.15 });
    document.querySelectorAll(".reveal").forEach((el, i) => {
      el.style.transitionDelay = `${(i % 4) * 70}ms`;
      io.observe(el);
    });
  }
  function countUp(el) {
    const target = +el.dataset.count;
    if (!target) { el.textContent = "0"; return; }
    const start = performance.now();
    const tick = (t) => {
      const p = Math.min(1, (t - start) / 1200);
      el.textContent = Math.round(target * (1 - Math.pow(1 - p, 3)));
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  /* ---------- 卡片光斑跟随鼠标 ---------- */
  function initCardGlow() {
    document.querySelectorAll(".card").forEach((card) => {
      card.addEventListener("pointermove", (e) => {
        const r = card.getBoundingClientRect();
        card.style.setProperty("--mx", `${e.clientX - r.left}px`);
        card.style.setProperty("--my", `${e.clientY - r.top}px`);
      });
    });
  }

  /* ---------- 首屏演示：模拟按住 ⌥ → 聆听 → 识别 → 输入 ---------- */
  const demoScripts = () => [
    { target: "typed1", caret: "caret1", text: t("demo.text1") },
    { target: "typed2", caret: "caret2", text: t("demo.text2"), send: true },
  ];

  // 边说边出字：中文每次出两三个字，英文每次出一个词
  const speechChunks = (text) =>
    (window.I18N.lang === "en" ? text.match(/\S+\s*/g) : text.match(/.{1,3}/gu)) || [];

  // 切换语言时递增；正在播放的一轮发现代数变了就中止，从头用新语言播放
  let demoGen = 0;
  const DEMO_ABORTED = Symbol("demo aborted");
  const demoSleep = async (ms, gen) => {
    await sleep(ms);
    if (gen !== demoGen) throw DEMO_ABORTED;
  };

  function hudSet(state, title, body) {
    const hud = $("hud");
    hud.dataset.state = state;
    $("hudTitle").textContent = title;
    $("hudBody").textContent = body;
    hud.classList.add("show");
  }
  const hudHide = () => $("hud").classList.remove("show");

  function setKey(down, hint) {
    $("keyOpt").classList.toggle("down", down);
    $("mbMic").classList.toggle("rec", down);
    $("keyHintText").textContent = hint;
  }

  async function runOnce(s, gen) {
    const target = $(s.target);
    target.textContent = "";
    for (const c of ["caret1", "caret2"]) $(c).classList.toggle("off", c !== s.caret);
    await demoSleep(900, gen);

    setKey(true, t("demo.holding"));
    hudSet("listening", t("hud.listening"), t("hud.release"));
    await demoSleep(700, gen);
    let partial = "";
    for (const ch of speechChunks(s.text)) {
      partial += ch;
      $("hudBody").textContent = partial;
      await demoSleep(260, gen);
    }
    await demoSleep(350, gen);

    setKey(false, t("demo.released"));
    hudSet("processing", t("hud.recognizing"), s.text);
    await demoSleep(800, gen);

    target.textContent = s.text;
    hudSet("success", t("hud.inserted"), s.text);
    await demoSleep(1000, gen);
    hudHide();
    setKey(false, t("demo.hint"));

    if (s.send) {
      await demoSleep(700, gen);
      const out = $("bubbleOut");
      out.textContent = s.text;
      out.hidden = false;
      target.textContent = "";
    }
    await demoSleep(1600, gen);
  }

  function resetDemo() {
    $("bubbleOut").hidden = true;
    $("typed1").textContent = "";
    $("typed2").textContent = "";
    hudHide();
    setKey(false, t("demo.hint"));
  }

  async function demoLoop() {
    const section = document.querySelector(".demo-section");
    document.addEventListener("langchange", () => {
      demoGen++;
      resetDemo();
    });
    for (;;) {
      const gen = demoGen;
      try {
        for (const s of demoScripts()) {
          await waitUntilActive(section);
          await runOnce(s, gen);
        }
        await demoSleep(1200, gen);
      } catch (e) {
        if (e !== DEMO_ABORTED) throw e;
      }
      resetDemo();
    }
  }

  function initClock() {
    const update = () => {
      const d = new Date();
      $("mbTime").textContent = `${t("demo.days")[d.getDay()]} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
    };
    update();
    setInterval(update, 30000);
    document.addEventListener("langchange", update);
  }

  /* ---------- 透明度滑块：与 App 菜单里的效果一致 ---------- */
  function initOpacityDemo() {
    const range = $("odRange");
    const apply = () => {
      const v = +range.value;
      $("odHud").style.setProperty("--hud-opacity", v / 100);
      $("odOut").textContent = `${v}%`;
      $("odTitle").textContent = t("opacity.title", { v });
    };
    range.addEventListener("input", apply);
    document.addEventListener("langchange", apply);
    apply();
  }

  function initSegment() {
    document.querySelectorAll(".seg").forEach((seg) => {
      seg.addEventListener("click", (e) => {
        if (e.target.tagName !== "SPAN") return;
        seg.querySelectorAll("span").forEach((s) => s.classList.toggle("on", s === e.target));
      });
    });
  }

  function initCopy() {
    document.querySelectorAll(".copy").forEach((btn) => {
      btn.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText($(btn.dataset.copy).textContent);
          btn.textContent = t("copy.done");
        } catch {
          btn.textContent = t("copy.fail");
        }
        setTimeout(() => (btn.textContent = t("copy.label")), 1600);
      });
    });
  }

  /* ---------- 剪贴板历史演示：选中行自动移动，鼠标移上去时跟随鼠标 ---------- */
  function initClipboardDemo() {
    const rows = [...document.querySelectorAll("#clipList li")];
    if (!rows.length) return;
    let index = 0;
    let hovering = false;
    const select = (i) => {
      index = i;
      rows.forEach((row, n) => row.classList.toggle("on", n === i));
    };
    rows.forEach((row, n) => row.addEventListener("pointerenter", () => select(n)));
    const list = $("clipList");
    list.addEventListener("pointerenter", () => (hovering = true));
    list.addEventListener("pointerleave", () => (hovering = false));
    if (reduceMotion) return;
    const section = $("clipboard");
    setInterval(() => {
      if (!hovering && isActive(section)) select((index + 1) % rows.length);
    }, 1600);
  }

  initOffscreenPause();
  initReveal();
  initCardGlow();
  initClock();
  initOpacityDemo();
  initSegment();
  initCopy();
  initClipboardDemo();
  demoLoop();
})();
