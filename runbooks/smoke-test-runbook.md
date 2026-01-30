# Session Smoke Test Runbook

Manual smoke test for control-plane session functionality.

## Prerequisites

```bash
# Verify CP is running
curl -s 'http://127.0.0.1:18420/admin/status' -H 'x-cp-token: dev' | jq .

# Confirm a project exists
curl -s 'http://127.0.0.1:18420/admin/projects' -H 'x-cp-token: dev' | jq '.[].projectId'
```

Set variables for the test:
```bash
BASE="http://127.0.0.1:18420"
TOKEN="x-cp-token: dev"
PROJECT="rex"  # adjust to your project
```

---

## Test 1: Establish Baseline

List existing sessions to know the starting state.

```bash
curl -s "$BASE/admin/sessions?projectId=$PROJECT" -H "$TOKEN" | jq 'length'
```

**Expected:** A number (could be 0).

---

## Test 2: Start a New Run (Creates Session)

```bash
curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"What is 2+2? Answer with just the number.\",
    \"session\": {
      \"policy\": \"new\",
      \"name\": \"Smoke Test Session\",
      \"aspTargetName\": \"smokey\"
    }
  }" | jq .
```

**Expected:**
```json
{ "runId": "...", "sessionId": "...", "status": "queued" }
```

**Capture the values:**
```bash
RUN_ID="<paste-runId>"
SESSION_ID="<paste-sessionId>"
```

---

## Test 3: Connect SSE Stream

In a **separate terminal**, connect to the event stream:

```bash
curl -N "$BASE/admin/sessions/$SESSION_ID/events/stream" \
  -H "$TOKEN" \
  -H 'Accept: text/event-stream'
```

**Expected:** Events stream as the run progresses (tool calls, content, completion).

---

## Test 4: Verify Session Created

```bash
curl -s "$BASE/admin/sessions/$SESSION_ID" -H "$TOKEN" | jq .
```

**Expected:**
```json
{
  "sessionId": "...",
  "projectId": "rex",
  "backendKind": "asp",
  "name": "Smoke Test Session",
  "source": { "kind": "batch" },
  "createdAt": ...
}
```

---

## Test 5: Wait for Run Completion

```bash
curl -s "$BASE/admin/runs/$RUN_ID/wait?timeoutMs=60000" -H "$TOKEN" | jq .
```

**Expected:**
```json
{
  "status": "completed",
  "completedAt": ...,
  "finalOutput": "4"
}
```

---

## Test 6: List Runs for Session

```bash
curl -s "$BASE/admin/sessions/$SESSION_ID/runs" -H "$TOKEN" | jq '.runs | length'
```

**Expected:** `1`

---

## Test 7: Resume Session with Follow-up

```bash
curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"What was my previous question?\",
    \"session\": {
      \"policy\": \"resume\",
      \"sessionId\": \"$SESSION_ID\"
    }
  }" | jq .
```

**Expected:** Same `sessionId`, new `runId`.

```bash
RUN_ID_2="<paste-new-runId>"
```

---

## Test 8: Wait for Second Run

```bash
curl -s "$BASE/admin/runs/$RUN_ID_2/wait?timeoutMs=60000" -H "$TOKEN" | jq .
```

**Expected:** Response references "2+2" or the previous question, proving context was maintained.

---

## Test 9: Verify Run Count Increased

```bash
curl -s "$BASE/admin/sessions/$SESSION_ID/runs" -H "$TOKEN" | jq '.runs | length'
```

**Expected:** `2`

---

## Test 10: Fetch Session Events

```bash
curl -s "$BASE/admin/sessions/$SESSION_ID/events" -H "$TOKEN" | jq '.events | length'
```

**Expected:** Multiple events from both runs.

---

## Test 11: Get Run Events

Fetch events for a specific run (uses `$RUN_ID` from Test 2):

```bash
curl -s "$BASE/admin/runs/$RUN_ID/events" -H "$TOKEN" | jq .
```

**Expected:**
```json
{
  "events": [...],
  "total": N,
  "hasMore": false
}
```

---

## Test 12: Filter Run Events by Type

```bash
curl -s "$BASE/admin/runs/$RUN_ID/events?types=tool_execution_start,tool_execution_end" \
  -H "$TOKEN" | jq .
```

**Expected:** Only returns events matching the specified types.

---

## Test 13: Paginate Run Events

```bash
curl -s "$BASE/admin/runs/$RUN_ID/events?limit=2&offset=0" -H "$TOKEN" | jq .
```

**Expected:** Returns max 2 events, `hasMore` indicates if more exist.

---

## Test 14: Invalid Run Returns 404

```bash
curl -s "$BASE/admin/runs/nonexistent-run/events" -H "$TOKEN" | jq .
```

**Expected:** `{"error":"run not found"}` with status 404.

---

## Test 15: Queue While Running

Start a long-running prompt (use bash sleep to ensure it takes time):

```bash
curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"Use Bash to run: for i in \$(seq 1 5); do echo \$i; sleep 1; done\",
    \"session\": {
      \"policy\": \"resume\",
      \"sessionId\": \"$SESSION_ID\"
    }
  }" | jq .
```

Immediately submit another run:

```bash
curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"Hello\",
    \"session\": {
      \"policy\": \"resume\",
      \"sessionId\": \"$SESSION_ID\"
    }
  }" | jq .
```

**Expected:** Second run is accepted with `status: "queued"`. It will execute after the first run completes.

```json
{ "runId": "...", "sessionId": "...", "status": "queued" }
```

Verify both complete:

```bash
# Wait for both runs
curl -s "$BASE/admin/sessions/$SESSION_ID/runs" -H "$TOKEN" | jq '.runs[] | {runId, status}'
```

---

## Test 16: Cancel and Resume

Start a run, cancel it, then resume:

```bash
# Start a long-running run
RESULT=$(curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"Use Bash to run: for i in \$(seq 1 30); do echo \$i; sleep 1; done\",
    \"session\": { \"policy\": \"new\", \"name\": \"Cancel Test\" }
  }")
echo "$RESULT" | jq .

CANCEL_RUN_ID=$(echo "$RESULT" | jq -r .runId)
CANCEL_SESSION_ID=$(echo "$RESULT" | jq -r .sessionId)

# Wait for it to start running (not just injecting)
sleep 5
curl -s "$BASE/admin/runs/$CANCEL_RUN_ID" -H "$TOKEN" | jq '.status'

# Cancel it
curl -s -X POST "$BASE/admin/runs/$CANCEL_RUN_ID/cancel" -H "$TOKEN" | jq .
```

**Expected:** Cancel succeeds when run is in `running` state.

Resume the cancelled session:

```bash
curl -s -X POST "$BASE/admin/runs" \
  -H "$TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"projectId\": \"$PROJECT\",
    \"prompt\": \"Hello\",
    \"session\": {
      \"policy\": \"resume\",
      \"sessionId\": \"$CANCEL_SESSION_ID\"
    }
  }" | jq .
```

**Expected:** New run starts successfully (session can be resumed after cancel).

---

## Success Criteria

| Test | Criteria |
|------|----------|
| Session creation | New session created with correct metadata |
| SSE streaming | Events flow in real-time during run |
| Run completion | Wait endpoint returns completed status with output |
| Session resume | Context maintained across runs |
| Run history | Runs accumulate correctly per session |
| Run events | Events returned for specific run with total count |
| Run events filtering | Type filter returns only matching events |
| Run events pagination | Limit/offset work correctly with hasMore flag |
| Run events 404 | Invalid run ID returns proper error |
| Run queuing | Additional runs queue and execute in order |
| Cancel + resume | Session can be resumed after a cancelled run |

---

## Cleanup

Sessions persist until manually cleaned or CP restart. No cleanup required for smoke testing.
