# EigenLua #31: table memory measurement

Measured 2026-10-09 at EigenLua `ff1b38d`, EigenScript 0.45.1 and pristine
PUC-Rio Lua 5.4.9 on x86-64 Linux 6.18.44/glibc 2.39.  **No runtime or front-end
code was changed.**  RSS is GNU `/usr/bin/time -v`'s `Maximum resident set
size`; every workload keeps its result reachable until process exit.  The
runner compiles the Lua source once, then times only the generated program, so
compiler RSS is excluded.

## Result in one sentence

An empty Lua table costs **80.5 B** in PUC Lua and **2,941.3 B** in EigenLua
(36.5x, least-squares RSS slope): the EigenLua record constructs three
EigenScript dictionaries plus one list, and native component experiments put
**79.9%** of that record's measured bytes in dictionaries.  Dense numeric
elements cost **94.2 B instead of 16.8 B**, consistent with EigenScript's
80-byte heap `Value` plus list slot/growth.  Sparse integer elements cost
**523.6 B instead of 37.8 B**, because EigenLua additionally string-encodes
each key and stores a two-Value `[key,value]` list.

## Method and reproduction

Run:

```sh
bash tools/cloud_setup.sh
bash tools/build_ref.sh
tools/measure/run-table-memory.sh | tee results.tsv
```

The driver uses `/usr/bin/time -v` once per fresh process.  `table-memory.lua`
is the identical source for reference and candidate.  `native-table-memory.eigs`
builds direct EigenScript dicts/lists, while `native-components.eigs` varies
only the record components.  `eigenscript-layout.c` prints compile-time C
layout sizes when compiled against the pinned EigenScript source.  Numbers
below are one complete cold-process run.  An independent rerun is recommended
when comparing a future allocator or value-model release; RSS is page-rounded.

Bytes/element are `(workload RSS - that implementation's zero-work RSS) /
element count`.  The empty-table result is instead the least-squares slope of
all four requested N values; its R² is shown to make the allocation-step noise
visible rather than hiding it.

## 1. Empty tables: per-table overhead

| N | PUC Lua peak KiB | EigenLua peak KiB |
|---:|---:|---:|
| 0 | 1,076 | 17,696 |
| 10,000 | 1,988 | 37,096 |
| 100,000 | 9,404 | 299,828 |
| 1,000,000 | 79,840 | 2,885,328 |

| implementation | fitted bytes/table | R² | ratio |
|---|---:|---:|---:|
| PUC Lua 5.4.9 | **80.489** | 0.99997276 | 1.00x |
| EigenLua / EigenScript 0.45.1 | **2,941.273** | 0.99999247 | **36.54x** |

The root array used to retain the tables is included in both slopes.  This is
the operational per-table cost seen by programs, not a `sizeof` estimate.
Subtracting the dense-element slopes as a rough root-slot correction would
still leave about 63.7 B/table for Lua and 2,847.0 B/table for EigenLua, and
does not alter the conclusion.

## 2. Elements and the constructs-style shape

| live workload | N | PUC peak KiB | EigenLua peak KiB | PUC B/element | EigenLua B/element | ratio |
|---|---:|---:|---:|---:|---:|---:|
| one dense array table | 1,000,000 | 17,464 | 109,736 | **16.781** | **94.249** | 5.62x |
| one string-key table | 1,000,000 | 111,192 | 220,096 | **112.759** | **207.258** | 1.84x |
| one sparse integer-key table (`2*i`) | 1,000,000 | 37,980 | 528,992 | **37.790** | **523.567** | 13.85x |
| 100,000 four-string-field tables | 400,000 fields | 20,152 | 375,976 | **48.835/field** | **917.197/field** | 18.78x |

The last row is **195.338 B/small table** in Lua versus **3,668.787 B/small
table** in EigenLua.  It intentionally uses four fixed string field names, as
case records do, so keys are interned/reused rather than charging a fresh
string per table.  The number includes each table's base representation; the
marginal cost above the fitted empty-table slope is about 28.7 B/field in Lua
and 181.9 B/field in EigenLua.

The reported 590 MB/89 MB constructs-file ratio is therefore not one universal
table multiplier.  Shape matters: empty records measured 36.5x, the four-field
case shape measured 18.8x per table, dense elements 5.6x, strings 1.8x, and
sparse integer keys 13.9x.

## 3. Where an EigenLua table goes

`lr_newtable` returns one outer dictionary with these ten fields:

| field(s) | role | allocation at creation |
|---|---|---|
| `id` | identity used by `tostring` and encoded table keys | immediate number |
| `a` | keys `1..#t`, including holes | empty EigenScript list |
| `h` | string-key hash part | empty EigenScript dict |
| `o` | all other keys, encoded string -> `[original key,value]` | empty EigenScript dict |
| `mt` | metatable | null immediate |
| `it`, `im`, `is` | traversal order list and numeric/string cursor maps | null; containers are lazy |
| `il`, `ih` | live hash count and array high-water mark | immediate numbers |

Thus `it`/`im`/`is` do not allocate their eventual containers on a never-
iterated table, but their three dictionary fields plus `il`/`ih` push the
outer record from its 8-slot minimum capacity to 16 slots.

### Native component variants (N=100,000)

Each result subtracts native EigenScript's 2,100 KiB zero-work RSS and divides
by N.  The root list used to keep objects alive is consistently present.

| native object kept per root slot | peak KiB | bytes/object |
|---|---:|---:|
| `{}` | 74,960 | **746.086** |
| `[]` | 24,976 | **234.250** |
| `{"a":[],"h":{},"o":{}}` | 243,912 | **2,476.155** |
| preceding + `id`,`mt` | 253,920 | **2,578.637** |
| exact ten-field `lr_newtable` shape | 276,140 | **2,806.170** |

The component arithmetic closes: three isolated dict costs plus one isolated
list cost are 2,472.5 B, within 0.15% of the measured 2,476.2 B `core3` record.
Relative to the directly measured 2,806.2 B full native record:

* three dictionaries (outer record, `h`, `o`): **2,238.3 B, 79.8%**;
* array list `a`: **234.3 B, 8.35%**;
* five iteration fields/capacity step (`full10 - base5`): **227.5 B, 8.11%**;
* `id`/`mt` and their record slots (`base5 - core3`): **102.5 B, 3.65%**.

These are RSS deltas, so they include allocator metadata and capacity slack;
that is precisely the resident cost at issue.  The full native record is close
to EigenLua's 100k empty-table delta (2,889.0 B/table).  The remaining 82.9 B
is generated-program/root/runtime noise.  This demonstrates that empty-table
inflation is overwhelmingly EigenScript container layout exposed by
EigenLua's four-container representation, rather than compiler-retained Lua
metadata.

### EigenScript-native separation

| shape | native EigenScript | EigenLua | conclusion |
|---|---:|---:|---|
| 1,000,000 empty `{}` objects | 722,692 KiB | 2,885,328 KiB | one native dict is ~1/4 of the four-container Lua record |
| 1,000,000 list numbers | 103,732 KiB | 109,736 KiB | 104.1 vs 94.2 B/element after respective baselines; essentially EigenScript Value/list cost |
| 1,000,000 string dict entries | 214,072 KiB | 220,096 KiB | 217.1 vs 207.3 B/element; essentially EigenScript dict cost |
| 100,000 native four-field dicts vs Lua tables | 115,056 KiB | 375,976 KiB | 1,156.7 vs 3,668.8 B/record; EigenLua's extra `a`,`h`,`o` record dominates |

EigenScript dicts accept string keys only, so there is no honest direct native
integer-key dict counterpart.  That limitation is exactly why EigenLua's `o`
representation stringifies a non-array integer and allocates a pair list.
Comparing candidate sparse and string rows isolates **316.31 B/entry** of
additional encoding/pair-list cost, or **60.4%** of the candidate sparse-entry
total.

## 4. Value slots, NaN boxing, arena, and observers

The C layout probe against v0.45.1 reports:

| C type/payload | bytes |
|---|---:|
| `Value` | **80** |
| `EigsSlot` (NaN-boxed environment/VM slot) | **8** |
| list payload inside `Value` | 16 |
| dict payload inside `Value` | 64 |
| `EnvHash` | 32 |
| `ObserverSlot` | 88 |

The 8-byte NaN-box is used for VM/environment slots, but EigenScript containers
hold `Value *`: stored numbers materialize 80-byte heap Values.  The measured
94.249 B dense-array increment is consequently 84.9% one `Value` before its
pointer slot, growth slack, and allocator metadata.  Native and EigenLua dense
rows agree, attributing this to EigenScript's value/container model (#1644),
not EigenLua lowering.

`eigenscript --api` does expose `heap_inuse` and `arena_stats`; the experiments
use RSS component variants because the requested comparison is resident peak
and because allocator/accounting boundaries do not match PUC Lua's.  No arena
scope is opened by these programs.  Observer metadata is **0 B per table or
element in these workloads**: v0.45.1 removed observer fields from `Value`;
the 88-byte `ObserverSlot` lives in an environment-owned, lazily allocated
array.  The million tables/elements are list/dict members, not independently
observed bindings.  Therefore observer metadata is not a candidate explanation
for this issue.

## 5. Ranked contributors and candidate fixes

1. **EigenScript dictionary layout exposed four times per table — 79.8% of
   the measured full native record (2,238.3/2,806.2 B).  Needs EigenScript for
   the underlying cost; partly EigenLua-fixable.**  Empty EigenScript dicts
   eagerly allocate minimum key/value arrays and an `EnvHash`; an EigenLua
   table immediately owns outer, `h`, and `o` dicts.  For #1644, give an empty
   dict a zero-allocation singleton/inline state and allocate buckets on first
   insertion.  Independently, EigenLua can lazily create `h` and especially
   `o`, or replace the outer string dictionary with a compact runtime record.
   The latter removes general dict lookup/capacity from fixed fields.

2. **Heap `Value` per container number — 80 B of the measured 94.249 B dense
   element cost (84.9%).  Needs EigenScript.**  NaN-boxing currently stops at
   VM/environment `EigsSlot`; list/dict arrays still store `Value *`.  Extend
   the value-model release (#1644) so container slots are 8-byte tagged
   `EigsSlot`s and only reference objects are pointers.  The measured target is
   close to Lua's 16.781 B/element; eliminating the 80-byte number object is
   the only change large enough to close most of the dense-array gap.

3. **Sparse non-string encoding and pair list — 316.31 extra B/entry versus
   EigenLua string entries, 60.4% of each 523.567 B sparse entry.
   EigenLua-fixable (best fix may need EigenScript typed dict keys).**  `o`
   creates an encoded string key and a separate `[key,value]` list for every
   entry.  A front-end/runtime improvement can use parallel key/value arrays
   or a typed numeric-key map, avoiding both objects; a general EigenScript
   dictionary accepting tagged keys would give the cleanest implementation.

The next contributor for empty tables is the five iteration-order fields'
outer-dict capacity step: **227.5 B, 8.11%**.  It is **EigenLua-fixable** by
moving all traversal state into one null-or-record sidecar, preserving its
current lazy allocation while keeping an untouched table's outer record under
the 8-entry capacity boundary.

## Upstream disposition

This report is the measurement payload for EigenScript value-model issue
**#1644**: it identifies the 80-byte heap `Value` in numeric container slots
and the ~746 B empty-dict resident cost with reproducer and measured shares.
The representation-choice items (lazy `h`/`o`, compact fixed record, traversal
sidecar, and sparse-key storage) belong to EigenLua follow-up work.  No fix is
included here because #31 explicitly requests a measurement-only branch.
