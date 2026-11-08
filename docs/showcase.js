// The opening of the site is a graph, running. The engine answers; this file places the answer and
// spells out the call that produced it. Nothing here knows an algorithm, so a wrong picture is a
// wrong answer from the library.

import { graphs, run } from "./engine/moongraph.js";
import { renderGraph } from "./render.js";
import { attachBoardMenu } from "./board-menu.js";

const board = document.querySelector("#board");
if (board) {
  const names = JSON.parse(graphs());
  const algorithms = [
    "bfs",
    "dijkstra",
    "mst",
    "coloring",
    "components",
    "pagerank",
    "topo",
    "euler",
    "cycles",
  ];

  let graphName = names[0];
  let algorithm = "dijkstra";
  let source = 0;
  let customText = "";
  let answer = null;

  const graphRow = document.querySelector("#graphs");
  const algoRow = document.querySelector("#algorithms");
  const noteLine = document.querySelector("#note");
  const echo = document.querySelector("#echo");
  const input = document.querySelector("#edges");

  for (const name of names) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.dataset.graph = name;
    chip.setAttribute("aria-pressed", String(name === graphName));
    chip.addEventListener("click", () => {
      graphName = name;
      customText = "";
      input.value = "";
      source = 0;
      press(graphRow, name);
      draw();
    });
    graphRow.append(chip);
  }

  const customChip = document.createElement("button");
  customChip.className = "chip";
  customChip.textContent = "yours";
  customChip.dataset.graph = "custom";
  customChip.setAttribute("aria-pressed", "false");
  customChip.addEventListener("click", () => {
    graphName = "custom";
    source = 0;
    press(graphRow, "custom");
    input.focus();
    draw();
  });
  graphRow.append(customChip);

  for (const id of algorithms) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = id;
    chip.dataset.algo = id;
    chip.setAttribute("aria-pressed", String(id === algorithm));
    chip.addEventListener("click", () => {
      algorithm = id;
      press(algoRow, id);
      draw();
    });
    algoRow.append(chip);
  }

  input.addEventListener("input", () => {
    customText = input.value.trim();
    if (customText) {
      graphName = "custom";
      source = 0;
      press(graphRow, "custom");
    }
    draw();
  });

  board.addEventListener("pick", (event) => {
    source = event.detail;
    draw();
  });

  function press(row, key) {
    for (const child of row.children) {
      child.setAttribute(
        "aria-pressed",
        String(child.dataset.graph === key || child.dataset.algo === key),
      );
    }
  }

  function stat(name, value) {
    const node = document.querySelector(`[data-stat="${name}"]`);
    if (node) node.textContent = value;
  }

  function draw() {
    answer = JSON.parse(run(graphName, algorithm, source, customText));
    renderGraph(board, answer, {
      source,
      weights: algorithm === "dijkstra" || algorithm === "mst",
    });
    // The readout under the board: the shape of the input, and of the answer.
    stat("graph", graphName === "custom" ? "yours" : graphName);
    stat("nodes", answer.nodes.length);
    stat("edges", answer.edges.length);
    stat("kind", answer.directed ? "directed" : "undirected");
    stat("chosen", answer.edges.filter((edge) => edge.on).length);
    noteLine.textContent = answer.note;
    echo.innerHTML = callFor(answer);
  }

  // A right click on the board asks the board: start here, copy this, keep the drawing.
  attachBoardMenu(board, {
    answer: () => answer,
    pick: (node) => {
      source = node;
      draw();
    },
  });

  const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  // The MoonBit call the board is answering, so the picture and the API sit side by side.
  function callFor(answer) {
    const build =
      graphName === "custom"
        ? `<span class="c"># the graph you drew: ${esc(customText) || "a few nodes"}</span>\n`
        : `<span class="c"># ${esc(graphName)} · ${answer.nodes.length} nodes, ${answer.edges.length} edges</span>\n`;
    const w = `g.weights(fn (cost) { cost })`;
    const lines = {
      bfs: `<span class="fn">@traverse.bfs_tree</span><span class="ar">(</span>g<span class="ar">, ${source})</span>`,
      dijkstra: `<span class="fn">@path.dijkstra</span><span class="ar">(</span>g<span class="ar">, ${source}, weight=${w})</span>`,
      mst: `<span class="fn">@tree.minimum_spanning</span><span class="ar">(</span>g<span class="ar">, weight=${w})</span>`,
      coloring: `<span class="fn">@color.greedy_coloring</span><span class="ar">(</span>g<span class="ar">)</span>`,
      components: `<span class="fn">@component.components</span><span class="ar">(</span>g<span class="ar">)</span>`,
      pagerank: `<span class="fn">@centrality.pagerank</span><span class="ar">(</span>g<span class="ar">)</span>`,
      topo: `<span class="fn">@dag.topological_order</span><span class="ar">(</span>g<span class="ar">)</span>`,
      euler: `<span class="fn">@cycle.is_eulerian</span><span class="ar">(</span>g<span class="ar">)</span>`,
      cycles: `<span class="fn">@cycle.girth</span><span class="ar">(</span>g<span class="ar">)</span>`,
    };
    return (
      build +
      lines[algorithm] +
      `\n<span class="ar">→</span> <span class="out">${esc(answer.note)}</span>`
    );
  }

  draw();
}
