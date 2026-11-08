// What a right click on a graph board is about: the node under the pointer, or the drawing as a
// whole. Both boards on the site answer the same way, so the vocabulary is learned once.

import { copy, instrument, saveSvg } from "./menu.js";

/** `(0, 1) (1, 2) …` — the shape the board's editor takes back. */
function pairs(answer) {
  return answer.edges.map((edge) => `(${edge.a}, ${edge.b})`).join(" ");
}

/**
 * @param {SVGElement} board    the drawing
 * @param {object} spec
 * @param {() => object} spec.answer  the answer currently on the board
 * @param {(node: number) => void} spec.pick  start the search somewhere else
 * @param {string} [spec.name]  what to call the file
 */
export function attachBoardMenu(board, spec) {
  // The menu is also reachable from the keyboard, so the board has to be able to hold the focus.
  board.tabIndex = 0;

  instrument(board, (event) => {
    const circle = event.target.closest?.("[data-node]");
    const node = circle ? Number(circle.dataset.node) : null;
    const answer = spec.answer() ?? { nodes: [], edges: [] };
    const items = [];

    if (node !== null) {
      items.push({
        label: "Start the search here",
        run: () => spec.pick(node),
      });
      items.push({ label: "Copy the node number", run: () => copy(String(node), `node ${node}`) });
      items.push({ separator: true });
    }

    items.push({
      label: "Copy the edge list",
      hint: `${answer.edges.length} edges`,
      run: () => copy(pairs(answer), "edge list"),
    });
    items.push({
      label: "Save the drawing as SVG",
      run: () => saveSvg(board, `${spec.name ?? "moongraph"}-board.svg`),
    });

    return {
      title: node !== null ? `node ${node}` : `${answer.nodes.length} nodes · ${answer.edges.length} edges`,
      items,
    };
  });
}
