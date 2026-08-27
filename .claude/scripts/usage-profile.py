# Usage profiler for Claude Code session transcripts.
# Sums token usage (input, cache create, cache read, output) per model,
# for the main session and every subagent, and prints per-turn averages.
#
# Usage:
#   python .claude/scripts/usage-profile.py <projects-dir> <session-id>
# Example:
#   python .claude/scripts/usage-profile.py \
#     "C:/Users/jdennen/.claude/projects/C--Users-jdennen-surveywts" \
#     1f696918-6044-42e3-a12a-6832e45296dc
#
# Find the session id: newest .jsonl file in the projects dir for the
# directory you ran the session in.

import json, sys, glob, os, collections

def scan(path):
    stats = collections.defaultdict(collections.Counter)
    turns = collections.Counter()
    for line in open(path, encoding='utf-8', errors='replace'):
        try:
            rec = json.loads(line)
        except Exception:
            continue
        msg = rec.get('message') or {}
        usage = msg.get('usage')
        if not usage:
            continue
        model = msg.get('model', '?')
        c = stats[model]
        c['input'] += usage.get('input_tokens', 0)
        c['cache_create'] += usage.get('cache_creation_input_tokens', 0)
        c['cache_read'] += usage.get('cache_read_input_tokens', 0)
        c['output'] += usage.get('output_tokens', 0)
        turns[model] += 1
    return stats, turns

def show(label, stats, turns):
    print(f"\n== {label} ==")
    for model, c in stats.items():
        if model == '<synthetic>':
            continue
        n = turns[model]
        avg_ctx = (c['cache_read'] + c['cache_create'] + c['input']) // max(n, 1)
        print(f"  {model}  turns={n}  avg_context/turn={avg_ctx:,}")
        for k in ('input', 'cache_create', 'cache_read', 'output'):
            print(f"    {k:12} {c[k]:>12,}")

base, sess = sys.argv[1], sys.argv[2]
s, t = scan(os.path.join(base, sess + '.jsonl'))
show('MAIN ' + sess, s, t)

total = collections.defaultdict(collections.Counter)
tturns = collections.Counter()
for m, c in s.items():
    total[m].update(c); tturns[m] += t[m]

for f in sorted(glob.glob(os.path.join(base, sess, 'subagents', 'agent-*.jsonl'))):
    s2, t2 = scan(f)
    show('SUB ' + os.path.basename(f), s2, t2)
    for m, c in s2.items():
        total[m].update(c); tturns[m] += t2[m]

show('TOTAL', total, tturns)
