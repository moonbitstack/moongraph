// The opening of the site is a graph, running. This file places what the compiled
// library computes and shows the call that produced it; it does not re-implement an
// algorithm, so a mistake on the board is a mistake in the library and shows up as one.

import { graphs, run } from "./engine/moongraph.js";

const board = document.querySelector("#board");
if (board) {
  const names = JSON.parse(graphs());
  const algorithms = [
    ["bfs", "bfs"],
    ["dijkstra", "dijkstra"],
    ["mst", "mst"],
    ["coloring", "coloring"],
    ["components", "components"],
    ["pagerank", "pagerank"],
    ["topo", "topo"],
    ["euler", "euler"],
    ["cycles", "cycles"],
  ];

  let graphName = names[0];
  let algorithm = "dijkstra";
  let source = 0;
  let customText = "";

  const graphRow = document.querySelector("#graphs");
  const algoRow = document.querySelector("#algorithms");
  const noteLine = document.querySelector("#note");
  const echo = document.querySelector("#echo");
  const input = document.querySelector("#edges");

  // A chip per offered graph, plus the one you are drawing.
  for (const name of names) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.setAttribute("aria-pressed", String(name === graphName));
    chip.dataset.graph = name;
    chip.addEventListener("click", () => {
      graphName = name;
      customText = "";
      input.value = "";
      source = 0;
      pressChip(graphRow, name);
      draw();
    });
    graphRow.append(chip);
  }
  const customChip = document.createElement("button");
  customChip.className = "chip";
  customChip.textContent = "draw your own";
  customChip.setAttribute("aria-pressed", "false");
  customChip.dataset.graph = "custom";
  customChip.addEventListener("click", () => {
    graphName = "custom";
    source = 0;
    pressChip(graphRow, "custom");
    input.focus();
    draw();
  });
  graphRow.append(customChip);

  for (const [id, label] of algorithms) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = label;
    chip.setAttribute("aria-pressed", String(id === algorithm));
    chip.dataset.algo = id;
    chip.addEventListener("click", () => {
      algorithm = id;
      pressChip(algoRow, id);
      draw();
    });
    algoRow.append(chip);
  }

  input.addEventListener("input", () => {
    customText = input.value.trim();
    if (customText) {
      graphName = "custom";
      source = 0;
      pressChip(graphRow, "custom");
    }
    draw();
  });

  function pressChip(row, key) {
    for (const child of row.children) {
      child.setAttribute("aria-pressed", String(child.dataset.graph === key || child.dataset.algo === key));
    }
  }

  function draw() {
    const answer = JSON.parse(run(graphName, algorithm, source, customText));
    const parts = [];
    parts.push('<rect x="20" y="20" width="560" height="560" fill="none" stroke="transparent"/>');
    for (const edge of answer.edges) {
      const a = answer.nodes[edge.a];
      const b = answer.nodes[edge.b];
      const klass = edge.on ? "edge on" : "edge";
      if (answer.directed) {
        // a short tick near the target marks the direction, so the topological order reads left to right
        const parts2 = parts;
        parts2.push(`<line class="${klass}" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"/>`);
        const ang = Math.atan2(b.y - a.y, b.x - a.x);
        const hx = b.x - 15 * Math.cos(ang);
        const hy = b.y - 15 * Math.sin(ang);
        const s = 7;
        const p1 = hx - s * Math.cos(ang - 0.5);
        const p2 = hy - s * Math.sin(ang - 0.5);
        const p3 = hx - s * Math.cos(ang + 0.5);
        const p4 = hy - s * Math.sin(ang + 0.5);
        parts2.push(`<path class="${klass}" d="M${p1} ${p2} L${hx} ${hy} L${p3} ${p4}" fill="none"/>`);
      } else {
        parts.push(`<line class="${klass}" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"/>`);
      }
    }
    if (algorithm === "dijkstra" || algorithm === "mst") {
      for (const edge of answer.edges) {
        const a = answer.nodes[edge.a];
        const b = answer.nodes[edge.b];
        const mx = (a.x + b.x) / 2;
        const my = (a.y + b.y) / 2;
        parts.push(`<text class="edge-w" x="${mx}" y="${my - 3}" text-anchor="middle">${edge.w}</text>`);
      }
    }
    const showsSource = algorithm === "bfs" || algorithm === "dijkstra" || algorithm === "topo";
    for (const node of answer.nodes) {
      if (node.i === source && showsSource) {
        parts.push(`<circle class="ring" cx="${node.x}" cy="${node.y}" r="19"/>`);
      }
      const klass = node.i === source ? "node picked" : "node";
      parts.push(`<circle class="${klass}" data-node="${node.i}" cx="${node.x}" cy="${node.y}" r="12"/>`);
      if (node.v) {
        parts.push(`<text class="label" x="${node.x}" y="${node.y + 34}" text-anchor="middle">${node.v}</text>`);
      }
    }
    board.innerHTML = parts.join("");
    for (const circle of board.querySelectorAll("[data-node]")) {
      circle.addEventListener("click", () => {
        source = Number(circle.dataset.node);
        draw();
      });
    }
    noteLine.textContent = answer.note + " Click a node to start somewhere else.";
    echo.innerHTML = callFor(answer);
  }

  function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // The MoonBit call that the board is answering, so the drawing and the API sit side by side.
  function callFor(answer) {
    const g = graphName === "custom" ? "g" : "g";
    const build = graphName === "custom"
      ? `<span class="c"># the graph you drew: ${esc(customText) || "a few nodes"}</span>\n`
      : `<span class="c"># ${esc(graphName)}: ${answer.nodes.length} nodes, ${answer.edges.length} edges</span>\n`;
    const w = `g.weights(fn (cost) { cost })`;
    const lines = {
      bfs: `<span class="fn">@traverse.bfs_tree</span><span class="ar">(</span>${g}<span class="ar">, ${source})</span>`,
      dijkstra: `<span class="fn">@path.dijkstra</span><span class="ar">(</span>${g}<span class="ar">, ${source}, weight=${w})</span>`,
      mst: `<span class="fn">@tree.minimum_spanning</span><span class="ar">(</span>${g}<span class="ar">, weight=${w})</span>`,
      coloring: `<span class="fn">@color.greedy_coloring</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
      components: `<span class="fn">@component.components</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
      pagerank: `<span class="fn">@centrality.pagerank</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
      topo: `<span class="fn">@dag.topological_order</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
      euler: `<span class="fn">@cycle.is_eulerian</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
      cycles: `<span class="fn">@cycle.girth</span><span class="ar">(</span>${g}<span class="ar">)</span>`,
    };
    return build + lines[algorithm] + `\n<span class="ar">→</span> <span class="out">${esc(answer.note)}</span>`;
  }

  draw();
}
