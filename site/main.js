(() => {
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const $ = (id) => document.getElementById(id);

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
  const SCRIPTS = [
    { target: "typed1", caret: "caret1", text: "修复登录页在深色模式下的显示问题" },
    { target: "typed2", caret: "caret2", text: "很顺利，今晚八点准时发布新版本", send: true },
  ];

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

  async function runOnce(s) {
    const target = $(s.target);
    target.textContent = "";
    for (const c of ["caret1", "caret2"]) $(c).classList.toggle("off", c !== s.caret);
    await sleep(900);

    setKey(true, "按住右 Option 说话…");
    hudSet("listening", "正在聆听…", "松开右 Option 结束");
    await sleep(700);
    // 边说边出字：按词组逐段更新识别中的文字
    const chunks = s.text.match(/.{1,3}/gu);
    let partial = "";
    for (const ch of chunks) {
      partial += ch;
      $("hudBody").textContent = partial;
      await sleep(260);
    }
    await sleep(350);

    setKey(false, "松开");
    hudSet("processing", "识别中…", s.text);
    await sleep(800);

    target.textContent = s.text;
    hudSet("success", "已输入", s.text);
    await sleep(1000);
    hudHide();
    setKey(false, "按住右 Option 说话");

    if (s.send) {
      await sleep(700);
      const out = $("bubbleOut");
      out.textContent = s.text;
      out.hidden = false;
      target.textContent = "";
    }
    await sleep(1600);
  }

  async function demoLoop() {
    const section = document.querySelector(".demo-section");
    for (;;) {
      for (const s of SCRIPTS) {
        await waitUntilActive(section);
        await runOnce(s);
      }
      await sleep(1200);
      $("bubbleOut").hidden = true;
      $("typed1").textContent = "";
    }
  }

  function initClock() {
    const days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    const update = () => {
      const d = new Date();
      $("mbTime").textContent = `${days[d.getDay()]} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
    };
    update();
    setInterval(update, 30000);
  }

  /* ---------- 透明度滑块：与 App 菜单里的效果一致 ---------- */
  function initOpacityDemo() {
    const range = $("odRange");
    const apply = () => {
      const v = +range.value;
      $("odHud").style.setProperty("--hud-opacity", v / 100);
      $("odOut").textContent = `${v}%`;
      $("odTitle").textContent = `悬浮窗透明度 ${v}%`;
    };
    range.addEventListener("input", apply);
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
          btn.textContent = "已复制";
        } catch {
          btn.textContent = "复制失败";
        }
        setTimeout(() => (btn.textContent = "复制"), 1600);
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
