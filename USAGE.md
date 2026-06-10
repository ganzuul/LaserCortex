# LaserCortex — Usage

## Lean Verification Binary

The Lean binary at `.lake/build/bin/lasercortex` reads a binary-encoded EMLTree
from stdin, checks that the tree contracts to its right-comb normal form
(`decidable_contracts_to tree (rightComb tree.size)`), and prints the result.

Build:

    lake build

Run:

    echo '<encoding>' | .lake/build/bin/lasercortex

Output is one line: `verified` or `failed`.

### Binary Encoding

Trees are encoded as a string of `0` and `1` characters (no delimiters):

| Bits | Meaning |
|------|---------|
| `0`  | Leaf    |
| `1`  | Node, followed by left subtree, then right subtree |

Examples:

| Tree | Encoding |
|------|----------|
| `Leaf` | `0` |
| `Node(Leaf, Leaf)` | `100` |
| `Node(Node(Leaf, Leaf), Leaf)` | `11000` |

The encoding is uniquely decodable: each `1` consumes exactly two subtrees,
each `0` consumes nothing.  Any trailing characters are ignored.

## Python Bridge

### `lean_verify(tree: EMLTree) -> bool`

Calls the Lean binary via `subprocess.run`, passing `tree.to_bits()` on stdin.

```python
from infra._cortex._types import lean_verify
from infra._cortex._eml_tree import EMLTree

t = EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
assert lean_verify(t)  # True
```

### `CortexCertificate.verify(use_lean=False)`

When `use_lean=True`, delegates final confirmation to the Lean binary after
checking the contraction path locally.

```python
from infra._cortex._types import certify

cert = certify(t)
cert.verify(use_lean=True)  # True
```

### `EMLTree.to_bits() -> str`

Produces the binary encoding consumed by the Lean binary.

```python
t = EMLTree.node(EMLTree.leaf(), EMLTree.leaf())
t.to_bits()  # "100"
```

## QC Adapter

`QCSignalAdapter` replays a QuantConnect-style MA-cross strategy (15/30 EMA)
against historical price data.  Every signal decision is instantiated as a
`CortexSpec` witness and verified through the Lean binary.

```python
from infra._cortex._qc_adapter import QCSignalAdapter, SignalConfig
from infra._cortex import NormCodeCortexBridge

bridge = NormCodeCortexBridge()
adapter = QCSignalAdapter(
    bridge,
    symbol="SPY",
    config=SignalConfig(fast_window=15, slow_window=30),
)
result = adapter.run(
    spec_name="sorites_threshold",
    start="2023-01-01",
    end="2023-03-31",
    checkpoint_every=21,
)
print(result.summary)
```

## FastAPI Router

Canvas backend exposes cortex endpoints at `/api/cortex/`:

| Endpoint | Description |
|----------|-------------|
| `GET  /api/cortex/specs` | List all seed specs |
| `GET  /api/cortex/specs/{name}` | Spec details with examples |
| `GET  /api/cortex/certificates` | List cached certificates |
| `GET  /api/cortex/certificates/{key}` | Single certificate details |
| `POST /api/cortex/instantiate` | Instantiate a spec with witness data |
| `GET  /api/cortex/bridge/state` | Full bridge state dump |
