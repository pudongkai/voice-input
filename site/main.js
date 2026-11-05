(() => {
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const $ = (id) => document.getElementById(id);

  /* ---------- 背景粒子：缓慢漂移的点，近距离时连线 ---------- */
  function initParticles() {
    const canvas = $("particles");
    const ctx = canvas.getContext("2d");
    let w, h, dots;
    const resize = () => {
      const dpr = Math.min(devicePixelRatio || 1, 2);
      w = innerWidth; h = innerHeight;
      canvas.width = w * dpr; canvas.height = h * dpr;
      canvas.style.width = w + "px"; canvas.style.height = h + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const count = Math.min(70, Math.floor((w * h) / 22000));
      dots = Array.from({ length: count }, () => ({
        x: Math.random() * w, y: Math.random() * h,
        vx: (Math.random() - 0.5) * 0.25, vy: (Math.random() - 0.5) * 0.25,
        r: Math.random() * 1.4 + 0.4,
      }));
    };
    const draw = () => {
      ctx.clearRect(0, 0, w, h);
      for (const d of dots) {
        d.x = (d.x + d.vx + w) % w; d.y = (d.y + d.vy + h) % h;
        ctx.beginPath(); ctx.arc(d.x, d.y, d.r, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(80,140,230,0.35)"; ctx.fill();
      }
      for (let i = 0; i < dots.length; i++) {
        for (let j = i + 1; j < dots.length; j++) {
          const a = dots[i], b = dots[j];
          const dist = Math.hypot(a.x - b.x, a.y - b.y);
          if (dist < 130) {
            ctx.strokeStyle = `rgba(80,140,230,${0.12 * (1 - dist / 130)})`;
            ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
          }
        }
      }
      requestAnimationFrame(draw);
    };
    resize();
    addEventListener("resize", resize);
    if (!reduceMotion) draw();
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
    const demo = $("demo");
    await new Promise((resolve) => {
      const io = new IntersectionObserver((es) => {
        if (es.some((e) => e.isIntersecting)) { io.disconnect(); resolve(); }
      }, { threshold: 0.3 });
      io.observe(demo);
    });
    for (;;) {
      for (const s of SCRIPTS) await runOnce(s);
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

  initParticles();
  initReveal();
  initCardGlow();
  initClock();
  initOpacityDemo();
  initSegment();
  initCopy();
  demoLoop();
})();
