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

def first_turn_prefix(path):
    """The entry fee: the frozen prefix the first request writes or reuses.

    cache_creation alone understates it when an earlier subagent in the same
    session already cached a shared prefix - the reused part then shows as
    cache_read. creation + read + input on the first usage line is the whole
    prefix either way.
    """
    for line in open(path, encoding='utf-8', errors='replace'):
        try:
            rec = json.loads(line)
        except Exception:
            continue
        u = (rec.get('message') or {}).get('usage')
        if u and 'cache_creation_input_tokens' in u:
            return (u.get('cache_creation_input_tokens', 0),
                    u.get('cache_read_input_tokens', 0),
                    u.get('input_tokens', 0))
    return None


if '--entry-fee' in sys.argv:
    sys.argv.remove('--entry-fee')
    base, sess = sys.argv[1], sys.argv[2]
    print('entry fee = first-turn cache_creation + cache_read + input')
    r = first_turn_prefix(os.path.join(base, sess + '.jsonl'))
    if r:
        print('  MAIN %-28s create=%8d read=%8d input=%6d  fee=%8d'
              % (sess[:28], r[0], r[1], r[2], sum(r)))
    for f in sorted(glob.glob(os.path.join(base, sess, 'subagents', 'agent-*.jsonl'))):
        r = first_turn_prefix(f)
        if r:
            print('  SUB  %-28s create=%8d read=%8d input=%6d  fee=%8d'
                  % (os.path.basename(f)[:28], r[0], r[1], r[2], sum(r)))
    sys.exit(0)

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
