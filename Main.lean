import LaserCortex

open EMLRegistry

instance : Inhabited (EMLTree × Nat) := ⟨(EMLTree.Leaf, 0)⟩

/--
Parse a tree from a binary preorder encoding string.
Encoding: '0' → Leaf, '1' → Node(parse left, parse right).
-/
partial def goParse (s : String) (pos : Nat) : EMLTree × Nat :=
  match String.Pos.Raw.get? s { byteIdx := pos } with
  | none => (EMLTree.Leaf, pos)
  | some '0' => (EMLTree.Leaf, pos + 1)
  | some '1' =>
    let (left, mid) := goParse s (pos + 1)
    let (right, endp) := goParse s mid
    (EMLTree.Node left right, endp)
  | some _ => (EMLTree.Leaf, pos + 1)

def parseTreeBits (s : String) : EMLTree :=
  (goParse s 0).1

/--
Verify that a tree contracts to its right-comb normal form.

Reads a line from stdin, parses it as a binary-encoded EMLTree,
checks `decidable_contracts_to tree (rightComb tree.size)`,
and prints "verified" or "failed".
-/
def main : IO Unit := do
  let stdin ← IO.getStdin
  let line ← stdin.getLine
  let tree := parseTreeBits ((String.trimAscii line).toString)
  let n := tree.size
  let target := rightComb n
  let result := decidable_contracts_to tree target
  if result then
    IO.println "verified"
  else
    IO.println "failed"
