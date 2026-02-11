# Ghostchat Identity Smoke Test

Automated smoke test for `ghostchat identity` and the enhanced `ghostchat list`.

## Prerequisites

```bash
# Verify ghostmux and ghostchat are installed
which ghostmux && which ghostchat

# Verify Ghostty API is reachable
ghostmux status
```

---

## Test 1: Baseline — list with no identities

```bash
# Clear own identity first
ghostchat identity --clear

ghostchat list
```

**Expected:** All terminals listed, none with `[role]` annotations.

---

## Test 2: Set identity on current terminal

```bash
ghostchat identity --role smoke-tester --project ghostmux --task smoke-test
```

**Expected:**
```
<your-name>  [smoke-tester]  project:ghostmux  task:smoke-test
```

---

## Test 3: Verify identity shows in list

```bash
ghostchat list
```

**Expected:** Your terminal line includes `[smoke-tester] smoke-test`.

---

## Test 4: Verify JSON output

```bash
ghostchat list --json | python3 -m json.tool
```

**Expected:** Your terminal entry has `"identity": {"role": "smoke-tester", "project": "ghostmux", "task": "smoke-test"}`.

---

## Test 5: Spawn tabs with identity

Spawn two new tabs, set identity on each via send-keys, then verify in list.

```bash
# Spawn tab A
TAB_A=$(ghostmux new --tab --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Tab A: $TAB_A"
sleep 1

# Set identity on tab A
ghostmux send-keys -t "$TAB_A" "ghostchat identity --role builder --project ghostmux --task build-feature"
sleep 1

# Spawn tab B
TAB_B=$(ghostmux new --tab --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Tab B: $TAB_B"
sleep 1

# Set identity on tab B
ghostmux send-keys -t "$TAB_B" "ghostchat identity --role tester --project ghostmux --task run-tests"
sleep 1
```

---

## Test 6: Verify all identities in list

```bash
ghostchat list
```

**Expected:** Three terminals show identity annotations:
- Your terminal: `[smoke-tester] smoke-test`
- Tab A: `[builder] build-feature`
- Tab B: `[tester] run-tests`

---

## Test 7: Verify JSON includes all identities

```bash
ghostchat list --json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for t in data['terminals']:
    ident = t.get('identity', {})
    if ident:
        print(f\"{t['name']:20s} role={ident.get('role',''):<15s} task={ident.get('task','')}\")
"
```

**Expected:** Three entries with role and task fields populated.

---

## Test 8: Partial identity (role only)

```bash
ghostmux send-keys -t "$TAB_A" "ghostchat identity --clear"
sleep 1
ghostmux send-keys -t "$TAB_A" "ghostchat identity --role observer"
sleep 1
ghostchat list
```

**Expected:** Tab A shows `[observer]` with no task suffix.

---

## Test 9: Clear identity

```bash
ghostmux send-keys -t "$TAB_A" "ghostchat identity --clear"
sleep 1
ghostchat list
```

**Expected:** Tab A no longer shows any identity annotation.

---

## Test 10: Identity JSON read

```bash
ghostchat identity --json | python3 -m json.tool
```

**Expected:**
```json
{
    "id": "<uuid>",
    "identity": {
        "project": "ghostmux",
        "role": "smoke-tester",
        "task": "smoke-test"
    },
    "name": "<your-name>"
}
```

---

## Cleanup

```bash
# Kill spawned tabs
ghostmux kill-surface -t "$TAB_A"
ghostmux kill-surface -t "$TAB_B"

# Clear own identity
ghostchat identity --clear
```

---

## Success Criteria

| Test | Criteria |
|------|----------|
| Baseline list | No identity annotations when none set |
| Set identity | Fields stored and echoed back |
| List with identity | Role and task appear in plain-text list |
| JSON list | Identity object present with correct fields |
| Spawned tabs | Identity set via send-keys is visible in list |
| Partial identity | Role-only displays correctly without task |
| Clear identity | Annotations removed from list |
| JSON read | Identity command returns structured JSON |
