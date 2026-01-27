---
name: browser-control
description: Control Chrome browser via the Control Plane's browser automation API. Use when automating web interactions, taking screenshots, extracting page content, or performing browser actions like clicking, typing, scrolling. Endpoints available at /browser/* on the Control Plane (default port 18420).
---

# Browser Control API

Automate Chrome via CDP (Chrome DevTools Protocol) using Playwright.

## Prerequisites

Chrome must be running with remote debugging:
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /browser/status | Check connection status |
| POST | /browser/connect | Connect to Chrome via CDP |
| GET | /browser/tabs | List open tabs |
| POST | /browser/navigate | Navigate to URL |
| GET | /browser/snapshot | Get AI-readable page snapshot |
| POST | /browser/screenshot | Capture screenshot (base64 PNG) |
| POST | /browser/act | Perform actions (click, type, etc.) |
| POST | /browser/evaluate | Execute JavaScript |
| POST | /browser/close | Close a page |

## Quick Start

```bash
# Check status
curl -s 'http://127.0.0.1:18420/browser/status' -H 'x-cp-token: dev'

# Connect to browser
curl -s -X POST 'http://127.0.0.1:18420/browser/connect' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' -d '{}'

# Navigate
curl -s -X POST 'http://127.0.0.1:18420/browser/navigate' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}'

# Get snapshot for AI analysis
curl -s 'http://127.0.0.1:18420/browser/snapshot' -H 'x-cp-token: dev'

# Screenshot (save to file)
curl -s -X POST 'http://127.0.0.1:18420/browser/screenshot' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"fullPage": true}' | jq -r '.image' | base64 -d > screenshot.png
```

## Actions (POST /browser/act)

| Action | Required | Optional | Example |
|--------|----------|----------|---------|
| click | ref | targetId | `{"kind":"click","ref":"#btn"}` |
| dblclick | ref | targetId | `{"kind":"dblclick","ref":".item"}` |
| type | ref, text | submit, targetId | `{"kind":"type","ref":"#input","text":"hello","submit":true}` |
| press | key | targetId | `{"kind":"press","key":"Enter"}` |
| hover | ref | targetId | `{"kind":"hover","ref":".menu"}` |
| select | ref, values | targetId | `{"kind":"select","ref":"#dropdown","values":["US"]}` |
| wait | timeMs or waitForText | targetId | `{"kind":"wait","waitForText":"Success"}` |
| scroll | - | direction, targetId | `{"kind":"scroll","direction":"down"}` |

### Element Reference Formats

The `ref` parameter accepts:
- **CSS selector**: `#id`, `.class`, `button`
- **Aria ref** (from snapshot): `e72` (pattern: `e<number>`)
- **XPath**: `/html/body/div/button` (starts with `/`)
- **Playwright pseudo**: `:has-text("Submit")`

### Action Examples

```bash
# Click button
curl -s -X POST 'http://127.0.0.1:18420/browser/act' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"kind":"click","ref":"#submit"}'

# Type and submit
curl -s -X POST 'http://127.0.0.1:18420/browser/act' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"kind":"type","ref":"#search","text":"query","submit":true}'

# Press key
curl -s -X POST 'http://127.0.0.1:18420/browser/act' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"kind":"press","key":"Escape"}'

# Wait for text
curl -s -X POST 'http://127.0.0.1:18420/browser/act' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"kind":"wait","waitForText":"Loading complete"}'

# Scroll down
curl -s -X POST 'http://127.0.0.1:18420/browser/act' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"kind":"scroll","direction":"down"}'
```

## Evaluate JavaScript

```bash
# Get page title
curl -s -X POST 'http://127.0.0.1:18420/browser/evaluate' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"expression":"document.title"}'

# Get all links
curl -s -X POST 'http://127.0.0.1:18420/browser/evaluate' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"expression":"Array.from(document.querySelectorAll(\"a\")).map(a=>a.href)"}'
```

## Tab Management

```bash
# List tabs
curl -s 'http://127.0.0.1:18420/browser/tabs' -H 'x-cp-token: dev'
# Response: {"ok":true,"tabs":[{"targetId":"page_abc123","url":"...","title":""}]}

# Close specific tab
curl -s -X POST 'http://127.0.0.1:18420/browser/close' \
  -H 'x-cp-token: dev' -H 'Content-Type: application/json' \
  -d '{"targetId":"page_abc123"}'
```

## Response Format

All endpoints return JSON:
```json
{"ok": true, ...}           // Success
{"ok": false, "error": "..."} // Error
```

## Workflow Example

```bash
# 1. Connect and navigate
curl -X POST 'http://127.0.0.1:18420/browser/connect' -H 'x-cp-token: dev' -H 'Content-Type: application/json' -d '{}'
curl -X POST 'http://127.0.0.1:18420/browser/navigate' -H 'x-cp-token: dev' -H 'Content-Type: application/json' -d '{"url":"https://github.com"}'

# 2. Get snapshot to find element refs
curl 'http://127.0.0.1:18420/browser/snapshot' -H 'x-cp-token: dev' | jq '.snapshot'

# 3. Interact using refs from snapshot
curl -X POST 'http://127.0.0.1:18420/browser/act' -H 'x-cp-token: dev' -H 'Content-Type: application/json' -d '{"kind":"click","ref":"e42"}'

# 4. Screenshot result
curl -X POST 'http://127.0.0.1:18420/browser/screenshot' -H 'x-cp-token: dev' -H 'Content-Type: application/json' -d '{}' | jq -r '.image' | base64 -d > result.png
```

## Notes

- Default CDP URL: `http://127.0.0.1:9222`
- Control Plane dev port: `18420`, stable port: `8420`
- `targetId` is a synthetic hash of the page URL (changes on navigation)
- Snapshot uses Playwright's `_snapshotForAI` when available, falls back to accessibility tree
