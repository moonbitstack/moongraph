// The instrument's own menu.
//
// A right click on a board is a question about the board, not an invitation to the browser's page
// menu: "Save page as", "Inspect", "Translate" are the wrong vocabulary here. So every surface the
// reader operates takes the native menu away and answers with this one instead, and the same
// handler takes the other native gestures with it — dragging a selection across the board, dragging
// the drawing out of the page, the middle-click autoscroll, the long-press callout on touch.

/**
 * Open a menu. One is open at a time; a second call replaces the first.
 *
 * @param {object} spec
 * @param {number} spec.x           where the pointer was, in viewport coordinates
 * @param {number} spec.y
 * @param {string} [spec.title]     the line above the items, naming what was clicked
 * @param {Array} spec.items        { label, hint, run } or { separator: true }
 * @param {Element} [spec.returnTo] where the focus goes when the menu closes
 */
export function openMenu(spec) {
  closeMenu();

  const menu = document.createElement("div");
  menu.className = "menu";
  menu.setAttribute("role", "menu");
  if (spec.title) menu.setAttribute("aria-label", spec.title);

  if (spec.title) {
    const title = document.createElement("div");
    title.className = "menu-title";
    title.textContent = spec.title;
    menu.append(title);
  }

  const buttons = [];
  for (const item of spec.items) {
    if (!item || item.separator) {
      const rule = document.createElement("div");
      rule.className = "menu-sep";
      rule.setAttribute("role", "separator");
      menu.append(rule);
      continue;
    }
    const button = document.createElement("button");
    button.type = "button";
    button.className = "menu-item";
    button.setAttribute("role", "menuitem");
    const label = document.createElement("span");
    label.textContent = item.label;
    button.append(label);
    if (item.hint) {
      const hint = document.createElement("span");
      hint.className = "key";
      hint.textContent = item.hint;
      button.append(hint);
    }
    button.addEventListener("click", () => {
      closeMenu();
      item.run();
    });
    menu.append(button);
    buttons.push(button);
  }

  document.body.append(menu);

  // Keep it on the page: below and right of the pointer where there is room, flipped where there
  // is not, and never over the edge.
  const box = menu.getBoundingClientRect();
  const gap = 8;
  const left = Math.min(spec.x, innerWidth - box.width - gap);
  const top = Math.min(spec.y, innerHeight - box.height - gap);
  menu.style.left = `${Math.max(gap, left)}px`;
  menu.style.top = `${Math.max(gap, top)}px`;
  menu.classList.add("open");

  current = { menu, returnTo: spec.returnTo ?? document.activeElement };
  current.onPointerDown = (event) => {
    if (!menu.contains(event.target)) closeMenu();
  };
  current.onKeyDown = (event) => {
    const at = buttons.indexOf(document.activeElement);
    if (event.key === "Escape") {
      event.preventDefault();
      closeMenu();
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      const next = at < 0 ? (step > 0 ? 0 : buttons.length - 1) : (at + step + buttons.length) % buttons.length;
      buttons[next].focus();
    } else if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      buttons[event.key === "Home" ? 0 : buttons.length - 1].focus();
    } else if (event.key === "Tab") {
      closeMenu();
    }
  };
  current.onDismiss = () => closeMenu();
  addEventListener("pointerdown", current.onPointerDown, true);
  addEventListener("keydown", current.onKeyDown, true);
  addEventListener("scroll", current.onDismiss, { capture: true, passive: true });
  addEventListener("resize", current.onDismiss);

  buttons[0]?.focus();
}

let current = null;

export function closeMenu() {
  if (!current) return;
  const { menu, returnTo, onPointerDown, onKeyDown, onDismiss } = current;
  current = null;
  removeEventListener("pointerdown", onPointerDown, true);
  removeEventListener("keydown", onKeyDown, true);
  removeEventListener("scroll", onDismiss, { capture: true });
  removeEventListener("resize", onDismiss);
  menu.remove();
  if (returnTo && returnTo.focus && document.contains(returnTo)) returnTo.focus({ preventScroll: true });
}

/** One line at the foot of the page, for what just happened. */
export function toast(message) {
  let node = document.querySelector(".toast");
  if (!node) {
    node = document.createElement("div");
    node.className = "toast";
    node.setAttribute("role", "status");
    node.setAttribute("aria-live", "polite");
    document.body.append(node);
  }
  node.textContent = message;
  node.classList.add("on");
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => node.classList.remove("on"), 1600);
}

/** Put text on the clipboard, and say so. */
export async function copy(text, what) {
  let done = false;
  try {
    await navigator.clipboard.writeText(text);
    done = true;
  } catch {
    // A page opened as a file, or a browser that withholds the async clipboard, still has the
    // old path: a selected textarea and one execCommand.
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.cssText = "position:fixed;top:-1000px;height:1px;width:1px;opacity:0";
    document.body.append(area);
    area.select();
    try {
      done = document.execCommand("copy");
    } catch {
      done = false;
    }
    area.remove();
  }
  toast(done ? `${what} copied` : `${what}: copy refused by the browser`);
  return done;
}

/**
 * Take one drawing out of the page as a standalone file.
 *
 * The page's stylesheet does not travel with the file, so the style of every mark is read off the
 * page and written onto the copy as attributes.
 */
export function saveSvg(svg, filename) {
  const clone = svg.cloneNode(true);
  const from = [svg, ...svg.querySelectorAll("*")];
  const to = [clone, ...clone.querySelectorAll("*")];
  const carried = [
    "fill", "fill-opacity", "stroke", "stroke-width", "stroke-dasharray", "stroke-linecap",
    "stroke-linejoin", "opacity", "font-family", "font-size", "letter-spacing", "paint-order",
    "text-anchor",
  ];
  from.forEach((element, at) => {
    const style = getComputedStyle(element);
    for (const property of carried) {
      const value = style.getPropertyValue(property);
      if (value && value !== "none" && value !== "normal") to[at].setAttribute(property, value);
    }
  });

  const viewBox = svg.viewBox.baseVal;
  const width = Math.round(viewBox.width || 600);
  const height = Math.round(viewBox.height || 600);
  clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
  clone.setAttribute("width", String(width));
  clone.setAttribute("height", String(height));
  clone.removeAttribute("class");
  clone.removeAttribute("style");

  // A drawing on transparent black is unreadable outside the page; the panel it sits on goes in,
  // over the frame the viewBox names rather than the file's own corner.
  const stage = svg.closest(".stage");
  const ground = document.createElementNS("http://www.w3.org/2000/svg", "rect");
  ground.setAttribute("x", String(viewBox.x));
  ground.setAttribute("y", String(viewBox.y));
  ground.setAttribute("width", String(viewBox.width || width));
  ground.setAttribute("height", String(viewBox.height || height));
  ground.setAttribute("fill", stage ? getComputedStyle(stage).backgroundColor : "none");
  clone.insertBefore(ground, clone.firstChild);

  const text = new XMLSerializer().serializeToString(clone);
  const url = URL.createObjectURL(new Blob([text], { type: "image/svg+xml" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
  toast(`${filename} saved`);
}

/**
 * Hand a surface to the instrument: no native menu, no selection, no drag, no autoscroll.
 *
 * `menu(event)` is asked what the click is about and answers `{ title, items }`, or nothing when
 * the surface has nothing to offer there. Touch and pen keep the native gestures suppressed but
 * get no menu: a long press that opens a panel mid-drag is worse than a long press that does
 * nothing.
 */
export function instrument(element, menu) {
  element.addEventListener("contextmenu", (event) => {
    event.preventDefault();
    if (event.pointerType && event.pointerType !== "mouse") return;
    const asked = menu(event);
    if (asked) openMenu({ ...asked, x: event.clientX, y: event.clientY, returnTo: element });
  });

  element.addEventListener("keydown", (event) => {
    if (event.key !== "ContextMenu" && !(event.shiftKey && event.key === "F10")) return;
    event.preventDefault();
    const box = element.getBoundingClientRect();
    const asked = menu({ target: element, clientX: box.left + box.width / 2, clientY: box.top + box.height / 2 });
    if (asked) openMenu({ ...asked, x: box.left + box.width / 2, y: box.top + box.height / 2, returnTo: element });
  });

  // A drag across a board is the board's gesture, not a way to select the page behind it.
  for (const name of ["selectstart", "dragstart", "dblclick"]) {
    element.addEventListener(name, (event) => event.preventDefault());
  }
  element.addEventListener("auxclick", (event) => event.preventDefault());
  element.addEventListener("mousedown", (event) => {
    if (event.button === 1) event.preventDefault();
  });
}
