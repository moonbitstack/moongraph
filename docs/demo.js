// The demo page: the library compiled to JavaScript draws this board.
//
// Nothing here re-implements a graph algorithm. The engine returns the nodes with their place and
// their number, and the edges the algorithm chose; render.js puts them where the answer says.

import { graphs, run } from "./engine/moongraph.js";
import { renderGraph } from "./render.js";
import { attachBoardMenu } from "./board-menu.js";

const board = document.querySelector("#board");
if (board) {
  const names = JSON.parse(graphs());
  const algorithms = ["bfs", "dijkstra", "mst", "coloring", "components", "pagerank"];

  let graphName = names[0];
  let algorithm = "dijkstra";
  let source = 0;
  let answer = null;

  const graphRow = document.querySelector("#graphs");
  const algoRow = document.querySelector("#algorithms");
  const noteLine = document.querySelector("#note");

  for (const name of names) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.setAttribute("aria-pressed", String(name === graphName));
    chip.addEventListener("click", () => {
      graphName = name;
      source = 0;
      press(graphRow, chip);
      draw();
    });
    graphRow.append(chip);
  }

  for (const name of algorithms) {
    const chip = document.createElement("button");
    chip.className = "chip";
    chip.textContent = name;
    chip.setAttribute("aria-pressed", String(name === algorithm));
    chip.addEventListener("click", () => {
      algorithm = name;
      press(algoRow, chip);
      draw();
    });
    algoRow.append(chip);
  }

  board.addEventListener("pick", (event) => {
    source = event.detail;
    draw();
  });

  function press(row, chip) {
    for (const other of row.children) {
      other.setAttribute("aria-pressed", String(other === chip));
    }
  }

  function stat(name, value) {
    const node = document.querySelector(`[data-stat="${name}"]`);
    if (node) node.textContent = value;
  }

  function draw() {
    answer = JSON.parse(run(graphName, algorithm, source, ""));
    renderGraph(board, answer, {
      source,
      weights: algorithm === "dijkstra" || algorithm === "mst",
    });
    stat("nodes", answer.nodes.length);
    stat("edges", answer.edges.length);
    stat("chosen", answer.edges.filter((edge) => edge.on).length);
    noteLine.textContent = answer.note + " Click a node to start somewhere else.";
  }

  attachBoardMenu(board, {
    answer: () => answer,
    pick: (node) => {
      source = node;
      draw();
    },
  });

  draw();
}
