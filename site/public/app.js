// csx.lou15.com: clock, try-on cursors, state switcher, reveals.
(() => {
  const $ = (s, r = document) => r.querySelector(s);

  // Menu bar clock, like the real one.
  const clock = $("#clock");
  const tick = () => {
    if (clock) clock.textContent = new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  };
  tick(); setInterval(tick, 15000);

  // Fade sections in as they arrive.
  const io = new IntersectionObserver((es) => es.forEach((e) => {
    if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
  }), { rootMargin: "0px 0px -8% 0px" });
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  // Toast.
  const toastEl = $("#toast");
  let toastTimer;
  const toast = (t) => {
    if (!toastEl) return;
    toastEl.textContent = t; toastEl.classList.add("show");
    clearTimeout(toastTimer); toastTimer = setTimeout(() => toastEl.classList.remove("show"), 2200);
  };

  // State switcher.
  const sw = $("#stateSwitch"), simg = $("#statesImg");
  if (sw && simg) {
    sw.addEventListener("click", (e) => {
      const b = e.target.closest("button"); if (!b || b.classList.contains("on")) return;
      sw.querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
      simg.classList.add("swap");
      const next = new Image(); next.src = `/img/states-${b.dataset.img}.png`;
      next.onload = () => { simg.src = next.src; requestAnimationFrame(() => simg.classList.remove("swap")); };
    });
  }

  const grid = $("#looks-grid"), filters = $("#filters"), desk = $("#desk");
  if (!grid && !desk) return;

  // A real CSS cursor from the same artwork the app draws.
  const cursorValue = (id, part, hot) => {
    const a = `url("/looks/${id}-${part}-c1.png")`, b = `url("/looks/${id}-${part}-c2.png")`;
    for (const fn of ["image-set", "-webkit-image-set"]) {
      const v = `${fn}(${a} 1x, ${b} 2x) ${hot[0]} ${hot[1]}, auto`;
      if (CSS.supports("cursor", v)) return v;
    }
    return `${a} ${hot[0]} ${hot[1]}, auto`;
  };

  let pinned = null;
  const root = document.documentElement;
  const wear = (l) => {
    if (!l) { root.classList.remove("trying"); return; }
    root.style.setProperty("--cur-arrow", cursorValue(l.id, "arrow", l.arrowHot));
    root.style.setProperty("--cur-hand", cursorValue(l.id, "hand", l.handHot));
    root.style.setProperty("--cur-text", cursorValue(l.id, "ibeam", l.ibeamHot));
    root.classList.add("trying");
  };

  const img = (l, part, scale) => {
    const sz = l[`${part === "hand" ? "hand" : part === "grab" ? "grab" : part}Size`] || [34, 42];
    const el = new Image();
    el.src = `/looks/${l.id}-${part}@4x.png`;
    el.width = Math.round(sz[0] * scale); el.height = Math.round(sz[1] * scale);
    el.alt = ""; el.loading = "lazy"; el.decoding = "async";
    if (l.pixel) el.className = "pix";
    return el;
  };

  fetch("/looks/looks.json").then((r) => r.json()).then((looks) => {
    // Desk clutter around the hero: a few real cursors floating about.
    if (desk) {
      const spots = [[6, 16, -8], [86, 14, 6], [12, 52, 4], [90, 48, -5], [4, 78, 7], [80, 80, -6], [26, 8, 10], [70, 6, -10]];
      const kaos = ["^ ω ^", "{ ^-^ }", "(¬_¬)", "(˘ω˘)"];
      const picks = ["neon-neon-pink", "metal-gold", "pixel-handheld", "glass-frosted", "dots-halo-neon", "pop-tangerine", "gradient-aurora", "animated-rainbow"];
      spots.forEach(([x, y, r], i) => {
        const l = looks.find((k) => k.id === picks[i]) || looks[i];
        let el;
        if (i % 3 === 1) {
          el = document.createElement("div"); el.className = "ghost";
          el.innerHTML = `<div class="win ${l.dark ? "dark" : ""}"><div class="bar"><i></i><i></i><i></i></div><div class="body"></div></div>`;
          el.querySelector(".body").append(img(l, i % 2 ? "hand" : "arrow", 1.3));
        } else if (i % 4 === 2) {
          el = document.createElement("span"); el.className = "kao"; el.textContent = kaos[i % kaos.length];
        } else {
          el = img(l, i % 2 ? "hand" : "arrow", 1.15); el.classList.add("c");
        }
        el.style.left = x + "%"; el.style.top = y + "%"; el.style.setProperty("--r", r + "deg");
        el.style.animationDelay = (-i * 0.9) + "s";
        desk.append(el);
      });
    }

    if (!grid) return;
    const cats = ["all", ...new Set(looks.map((l) => l.category))];
    let cat = "all";
    const render = () => {
      grid.innerHTML = "";
      looks.filter((l) => cat === "all" || l.category === cat).forEach((l) => {
        const card = document.createElement("div");
        card.className = "look" + (l.category === "glass" ? " glass" : "") + (pinned === l.id ? " on" : "");
        card.tabIndex = 0;
        card.innerHTML = `<div class="win ${l.dark ? "dark" : ""}"><div class="bar"><i></i><i></i><i></i><b>${l.name}</b></div><div class="stage"></div></div>
          <div class="meta"><span class="state">${pinned === l.id ? "wearing" : l.category}</span><span>hover to try</span></div>`;
        const stage = card.querySelector(".stage");
        const colA = img(l, "arrow", 1.6);
        const col1 = document.createElement("div"); col1.className = "col"; col1.append(img(l, "hand", 0.95), img(l, "ibeam", 0.9));
        const col2 = document.createElement("div"); col2.className = "col"; col2.append(img(l, "wait", 0.8), img(l, "grab", 0.9));
        stage.append(colA, col1, col2);
        card.addEventListener("mouseenter", () => wear(l));
        card.addEventListener("mouseleave", () => wear(looks.find((k) => k.id === pinned)));
        card.addEventListener("click", () => {
          pinned = pinned === l.id ? null : l.id;
          toast(pinned ? `wearing ${l.name} on this page` : "back to your own cursor");
          render();
          wear(looks.find((k) => k.id === pinned) || l);
        });
        card.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); card.click(); } });
        grid.append(card);
      });
    };
    filters.innerHTML = cats.map((c) => `<button data-c="${c}" class="${c === cat ? "on" : ""}">${c}<em>${c === "all" ? looks.length : looks.filter((l) => l.category === c).length}</em></button>`).join("");
    filters.addEventListener("click", (e) => {
      const b = e.target.closest("button"); if (!b) return;
      cat = b.dataset.c;
      filters.querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
      render();
    });
    render();
  });
})();
