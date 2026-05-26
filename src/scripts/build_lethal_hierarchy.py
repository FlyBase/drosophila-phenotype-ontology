#!/usr/bin/env python3
"""
Compute the subClassOf hierarchy among the lethal_phase terms from
patterns/data/default/dpoIncreasedMortality.tsv plus the FBdv stage
graph, and emit a ROBOT template TSV. Pass the template through
`robot template ...` to produce components/lethal_class_hierarchy.owl.

Subsumption rule. For two rows, where each row has a relation kind
(rel), an FBdv stage (stage), and a mortality range bounded by a
required rate_min (inclusive) and an optional rate_max (exclusive):

    A ⊑ B   iff   stage_A specialises stage_B under their relation types
            AND   A's mortality range is contained in B's.

Stage specialisation:

    during(X) ⊑ during(Y)   iff X is reflexive-substage-of Y (via FBdv:00018001)
    before(X) ⊑ before(Y)   iff X equals Y or X precedes* Y
    during(X) ⊑ before(Y)   iff some substage-ancestor of X
                                strictly precedes* Y

"precedes" covers BFO:0000063 and any rdfs:subPropertyOf descendant of it
(e.g. RO:0002090 immediately_precedes), plus inverses via BFO:0000062
(e.g. RO:0002087 immediately_preceded_by). The exact predicate set is
read at build time from the RO mirror, so a new precedes-family
predicate is picked up automatically.

`during` and `during_substage` columns in the table map to the same
"during" relation here (different OWL properties, same hierarchy
semantics). A row with no stage column filled (FBcv:0002004) is the
umbrella: trivially specialised by any range-compatible term.

Two hardcoded parent edges (not inferable from the table) connect the
lethal subhierarchy to the broader FBcv hierarchy:

  - Lethal terms with no in-set parent get PHENOTYPE_PARENT_FOR_TOP_LEVEL.
    In practice this fires only for FBcv:0002004 -> FBcv:0001347.
  - EXTRA_PARENTS adds further per-term parents. Currently:
    FBcv:0000350 'partially lethal - majority live' -> FBcv:0000349 viable.

Usage:
    build_lethal_hierarchy.py LETHAL_TABLE.tsv FBDV.owl RO.owl OUT_TEMPLATE.tsv [--debug]
"""
import csv
import sys
from collections import defaultdict
from functools import lru_cache
from oaklib import get_adapter


# All entities are referred to by CURIE throughout: the table uses CURIEs,
# OAK works in CURIE space, and ROBOT templates accept CURIEs directly.
SUBSTAGE_OF = "FBdv:00018001"   # X substage_of Y means X happens during Y
PRECEDES = "BFO:0000063"        # root of the temporal-precedence family (incl. RO subproperties)
PRECEDED_BY = "BFO:0000062"     # root of the inverse family

# Extra parent edges added after table-driven subsumption, to connect the
# lethal subhierarchy to the broader FBcv hierarchy.
# - PHENOTYPE_PARENT_FOR_TOP_LEVEL is given to every lethal term that has
#   no parent within the lethal set (in practice, only FBcv:0002004).
# - EXTRA_PARENTS adds further parents on a per-term basis.
PHENOTYPE_PARENT_FOR_TOP_LEVEL = "FBcv:0001347"
EXTRA_PARENTS = {
    "FBcv:0000350": ["FBcv:0000349"],  # 'partially lethal - majority live' -> viable
}


def _subproperty_descendants(ro_path, parent_curie):
    """Walk rdfs:subPropertyOf transitively from parent_curie in the RO
    mirror, returning the set of CURIEs (parent + all descendants)."""
    import rdflib
    g = rdflib.Graph().parse(ro_path, format="xml")
    obo = "http://purl.obolibrary.org/obo/"
    root = rdflib.URIRef(obo + parent_curie.replace(":", "_"))
    out, stack = {root}, [root]
    while stack:
        for s in g.subjects(rdflib.RDFS.subPropertyOf, stack.pop()):
            if s not in out:
                out.add(s)
                stack.append(s)
    return {str(u).replace(obo, "", 1).replace("_", ":", 1) for u in out}


def make_stage_oracle(fbdv_path, ro_path):
    """
    Return (during_anc, before_anc_strict) functions, each mapping a
    stage CURIE to a frozenset of stage CURIEs:
      - during_anc:        reflexive transitive closure of substage_of
      - before_anc_strict: strict transitive closure of "precedes" across
                           the full RO precedes-family (forward + inverse).
    The precedes scan walks every FBdv edge once; the predicate filter
    keeps it cheap. We can't usefully scope by the lethal signature
    because precedes chains run through intermediate stages that aren't
    themselves lethal-table entries.
    """
    oi = get_adapter(f"pronto:{fbdv_path}")

    @lru_cache(maxsize=None)
    def during_anc(stage):
        return frozenset(oi.ancestors(stage, predicates=[SUBSTAGE_OF]))

    forward_preds = _subproperty_descendants(ro_path, PRECEDES)
    inverse_preds = _subproperty_descendants(ro_path, PRECEDED_BY)

    precedes_next = defaultdict(set)
    for s, p, o in oi.relationships():
        if p in forward_preds:
            precedes_next[s].add(o)
        elif p in inverse_preds:
            precedes_next[o].add(s)

    @lru_cache(maxsize=None)
    def before_anc_strict(stage):
        seen, stack = set(), [stage]
        while stack:
            for nxt in precedes_next.get(stack.pop(), ()):
                if nxt not in seen:
                    seen.add(nxt)
                    stack.append(nxt)
        return frozenset(seen)

    return during_anc, before_anc_strict


def load_table(path):
    """Parse the TSV into per-term dicts. `during` and `during_substage`
    merge into one field; rel/stage derived for use by stage_subsumes.
    rate_max_exclusive is the real upper bound; rate_max_inclusive=100
    is the sentinel for "no upper bound" and treated as None here."""
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f, delimiter="\t"):
            before = r["before"] or None
            during = r["during"] or r["during_substage"] or None
            if before and during:
                print(f"WARNING {r['defined_class']} has both during and before set",
                      file=sys.stderr)
            rows.append({
                "defined_class": r["defined_class"],
                "label": r["label"],
                "rel": "during" if during else "before" if before else None,
                "stage": during or before,
                "rate_min": int(r["rate_min"]) if r["rate_min"] else None,
                "rate_max": int(r["rate_max_exclusive"]) if r["rate_max_exclusive"] else None,
            })
    return rows


def stage_subsumes(rel_a, stage_a, rel_b, stage_b,
                   during_anc, before_anc_strict):
    """Stage-component subsumption: does A's (rel_a, stage_a) imply B's
    (rel_b, stage_b)? rel is "during" | "before" | None (no stage). All
    stages are CURIEs."""
    if rel_b is None:                      # B unconstrained: A trivially fits.
        return True
    if rel_a is None:                      # A unconstrained but B isn't.
        return False
    if rel_a == "during" and rel_b == "during":
        return stage_b in during_anc(stage_a)
    if rel_a == "before" and rel_b == "before":
        # Reflexive: before(X) ⊑ before(X).
        return stage_a == stage_b or stage_b in before_anc_strict(stage_a)
    if rel_a == "during" and rel_b == "before":
        # Strict: "during X" never implies "before X"; need some substage-
        # ancestor of stage_a to strictly precede stage_b.
        return any(stage_b in before_anc_strict(anc)
                   for anc in during_anc(stage_a))
    return False  # before(X) ⊑ during(Y) doesn't hold in general.


def range_subsumes(low_a, high_a, low_b, high_b):
    """Is A's mortality range contained in B's? high_b=None means
    unbounded above (B has no rate_max)."""
    if low_b is not None:
        if low_a is None or low_a < low_b:
            return False
    if high_b is not None:
        if high_a is None or high_a > high_b:
            return False
    return True


def main():
    args = sys.argv[1:]
    debug = "--debug" in args
    args = [a for a in args if a != "--debug"]
    if len(args) != 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    table_path, fbdv_path, ro_path, out_path = args

    rows = load_table(table_path)
    during_anc, before_anc_strict = make_stage_oracle(fbdv_path, ro_path)

    # All-pairs subsumption check.
    parents = defaultdict(set)
    for a in rows:
        for b in rows:
            if a["defined_class"] == b["defined_class"]:
                continue
            if (stage_subsumes(a["rel"], a["stage"], b["rel"], b["stage"],
                               during_anc, before_anc_strict)
                    and range_subsumes(a["rate_min"], a["rate_max"],
                                       b["rate_min"], b["rate_max"])):
                parents[a["defined_class"]].add(b["defined_class"])

    # Transitive reduction: keep p as a parent of c only if no other
    # parent of c also has p as an ancestor.
    direct = {
        c: {p for p in ps
            if not any(p in parents.get(q, ()) for q in ps if q != p)}
        for c, ps in parents.items()
    }

    # Connect to the broader FBcv hierarchy via hardcoded edges.
    for r in rows:
        c = r["defined_class"]
        if not direct.get(c):
            direct.setdefault(c, set()).add(PHENOTYPE_PARENT_FOR_TOP_LEVEL)
    for c, extras in EXTRA_PARENTS.items():
        direct.setdefault(c, set()).update(extras)

    # ROBOT template: header row + directive row, then one (child, parent)
    # row per subClassOf edge. External parents are auto-declared by ROBOT.
    lethal_curies = sorted(r["defined_class"] for r in rows)
    n_edges = sum(len(v) for v in direct.values())
    with open(out_path, "w") as f:
        f.write("ID\tParent Class\n")
        f.write("ID\tSC %\n")
        for c in lethal_curies:
            for p in sorted(direct.get(c, ())):
                f.write(f"{c}\t{p}\n")
    print(f"Wrote template for {len(rows)} classes, {n_edges} subClassOf edges to {out_path}",
          file=sys.stderr)

    if debug:
        for c in sorted(direct):
            for p in sorted(direct[c]):
                print(f"{c}\t{p}")


if __name__ == "__main__":
    main()
