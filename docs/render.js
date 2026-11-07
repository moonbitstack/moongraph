// One drawing for the whole site. The engine hands back nodes with a place and a number, and the
// edges the answer chose; this file only puts them where the answer says. Nothing here knows what
// Dijkstra is, so a wrong picture is a wrong answer from the library.

const SVGNS = "http://www.w3.org/2000/svg";

/**
 * Draw one answered graph into an <svg>.
 *
 * @param {SVGElement} svg    the element to fill
 * @param {object} answer     { nodes:[{i,x,y,v}], edges:[{a,b,w,on}], directed, note }
 * @param {object} options    { source, weights }
 */
export function renderGraph(svg, answer, options = {}) {
  const { source = -1, weights = false } = options;
  const at = (i) => answer.nodes[i];
  const parts = [];

  // A soft glow under the chosen route, so the answer reads as light rather than as a line.
  parts.push(`<defs>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="3.2" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>`);

  const chosen = [];
  for (const edge of answer.edges) {
    const a = at(edge.a);
    const b = at(edge.b);
    if (!a || !b) continue;
    parts.push(`<line class="edge${edge.on ? " on" : ""}" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"/>`);
    if (edge.on) {
      chosen.push(`<line class="flow" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"/>`);
      if (answer.directed) {
        // A tick near the head marks the direction, so a topological order reads left to right.
        const ang = Math.atan2(b.y - a.y, b.x - a.x);
        const hx = b.x - 16 * Math.cos(ang);
        const hy = b.y - 16 * Math.sin(ang);
        const s = 6;
        const p1 = [hx - s * Math.cos(ang - 0.5), hy - s * Math.sin(ang - 0.5)];
        const p3 = [hx - s * Math.cos(ang + 0.5), hy - s * Math.sin(ang + 0.5)];
        parts.push(`<path class="edge on" d="M${p1[0]} ${p1[1]} L${hx} ${hy} L${p3[0]} ${p3[1]}"/>`);
      }
    }
  }

  if (weights) {
    for (const edge of answer.edges) {
      const a = at(edge.a);
      const b = at(edge.b);
      if (!a || !b) continue;
      // Beside the edge, on the side that keeps the label clear of the number under the node.
      const mx = (a.x + b.x) / 2;
      const my = (a.y + b.y) / 2;
      const upright = Math.abs(b.x - a.x) < Math.abs(b.y - a.y);
      const wx = upright ? mx + 10 : mx;
      const wy = upright ? my + 4 : my - 7;
      parts.push(`<text class="edge-w" x="${wx}" y="${wy}" text-anchor="middle">${edge.w}</text>`);
    }
  }

  // The flowing dots go over the edges and under the nodes.
  parts.push(...chosen);

  for (const node of answer.nodes) {
    parts.push(`<circle class="node${node.i === source ? " picked" : ""}" data-node="${node.i}"
      cx="${node.x}" cy="${node.y}" r="11"/>`);
    if (node.v) {
      parts.push(`<text class="label" x="${node.x}" y="${node.y + 30}" text-anchor="middle">${node.v}</text>`);
    }
  }

  if (source >= 0 && answer.nodes[source]) {
    const s = answer.nodes[source];
    parts.push(`<circle class="ring" cx="${s.x}" cy="${s.y}" r="18"/>`);
  }

  // Crop the frame to the drawing, so a small graph is drawn as large as a big one.
  if (answer.nodes.length > 0) {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const node of answer.nodes) {
      x0 = Math.min(x0, node.x); y0 = Math.min(y0, node.y);
      x1 = Math.max(x1, node.x); y1 = Math.max(y1, node.y);
    }
    const pad = 42;
    svg.setAttribute(
      "viewBox",
      `${x0 - pad} ${y0 - pad} ${x1 - x0 + pad * 2} ${y1 - y0 + pad * 2}`,
    );
  }

  svg.innerHTML = parts.join("");
  for (const circle of svg.querySelectorAll("[data-node]")) {
    circle.addEventListener("click", () => {
      svg.dispatchEvent(new CustomEvent("pick", { detail: Number(circle.dataset.node) }));
    });
  }
}

/**
 * Draw a board and the route a search found on it.
 *
 * Cell numbers run left to right, then down. The route may skip cells — the any-angle search does
 * — so the line is drawn through the centres of the cells it names.
 */
export function renderBoard(svg, board, route, walls) {
  const { width, height, cell = 26 } = board;
  const pad = 1;
  const w = width * cell;
  const h = height * cell;
  const centre = (id) => ({
    x: (id % width) * cell + cell / 2,
    y: Math.floor(id / width) * cell + cell / 2,
  });

  const parts = [];
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const id = y * width + x;
      const blocked = walls.has(id);
      parts.push(
        `<rect class="cell${blocked ? " wall" : ""}" data-cell="${id}" x="${x * cell + pad}" y="${y * cell + pad}"
           width="${cell - pad * 2}" height="${cell - pad * 2}" rx="3"/>`,
      );
    }
  }

  if (route && route.length > 1) {
    const d = route.map((id, i) => `${i === 0 ? "M" : "L"}${centre(id).x} ${centre(id).y}`).join(" ");
    parts.push(`<path class="route" d="${d}"/>`);
    parts.push(`<path class="route-flow" d="${d}"/>`);
  }

  // The two ends of the errand, marked so the board reads without a legend.
  if (Number.isInteger(board.start)) {
    const s = centre(board.start);
    parts.push(`<circle class="mark start" cx="${s.x}" cy="${s.y}" r="5"/>`);
  }
  if (Number.isInteger(board.goal)) {
    const g = centre(board.goal);
    parts.push(`<circle class="mark goal" cx="${g.x}" cy="${g.y}" r="6.5"/>`);
    parts.push(`<circle class="mark goal-in" cx="${g.x}" cy="${g.y}" r="2.5"/>`);
  }

  svg.setAttribute("viewBox", `0 0 ${w} ${h}`);
  svg.innerHTML = parts.join("");
}
