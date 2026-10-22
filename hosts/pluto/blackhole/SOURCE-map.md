# Source map: 506e87fa7d ↔ lab observations (CVE-2026-109618/619)

**Commit:** `506e87fa7d` — *Avoid state corruption via bailout*  
**Tags:** `php-8.4.26` (vuln) → `php-8.4.27` (patched)

## Vendor test anchor

Our HTTP probe mirrors `tests/basic/oom_rfc1867_upload_progress.phpt`:

- Preamble: `PHPSESSID` + `PHP_SESSION_UPLOAD_PROGRESS` (= `k` → key **`upload_progress_k`**).
- Many small file parts → **`$_SESSION[upload_progress_k]['files']` grows**; **whole session re-encoded on each update** (`session.upload_progress.freq=1` in lab ini).
- Expect **soft `memory_limit` fatals**, not hard-limit death (patched builds must still reach `fileupload_done` cleanup).

## Call chain (upload progress → session file)

```text
sapi_handle_post()
  → rfc1867 multipart parser (main/rfc1867.c)
       → php_rfc1867_callback() [ext/session/session.c]
            MULTIPART_EVENT_FILE_* / FORMDATA
              → php_session_rfc1867_update()
                   → php_session_initialize()
                   → zend_hash_update(http_session_vars, upload_progress_*)
                   → php_session_flush(1)
                        → php_session_save_current_state()
                        → ps_mod_files.s_write → ps_files_write()
                             → ps_files_open() → flock(LOCK_EX) on /tmp/sess_<id>
                             → write serialized blob
                             → ps_files_close() → LOCK_UN + close
            MULTIPART_EVENT_END
              → php_session_rfc1867_cleanup() or final update (done=1)
              → php_rshutdown_session_globals()
              → [8.4.27+] zend_delete_global_variable("_SESSION")
```

## 8.4.26 failure mode (matches lab v4–v6)

| Mechanism | 8.4.26 | Effect in lab |
|-----------|--------|----------------|
| OOM during multipart | Often **`zend_bailout()`** mid-request (no `execute_data` → delayed OOM still bails) | OOM fatal in body; **parser/session cleanup incomplete** |
| `php_session_rfc1867_update()` | **`php_session_initialize()` + force `php_session_active`** without failure/`in_rfc1867_update` guards | Partial **`upload_progress_k`** flushed (`done=0`, huge `files[]`) — **~209 KiB `sess_*`** |
| `MULTIPART_EVENT_END` / cleanup | **Skipped** on bailout before `fileupload_done` | **`php_session_rfc1867_cleanup` never runs**; stale progress left in file |
| `mod_files` | **`flock(LOCK_EX)`** on session path (`FILE_PREFIX "sess_"`) | Wedged worker: **`locks_lock_inode_wait`**, FD **12 → `/tmp/sess_…`** |
| Follow-up request (same `PHPSESSID`) | Another worker (or same) opens same **`sess_*`** | **Blocks on lock** → client hang (v2); pool exhaustion |

Stale **`/tmp/php*`** paths inside serialized session (v6) are **metadata** from partial progress; live temps mostly gone — **logical state on disk ≠ runtime cleanup**.

## 8.4.27 fixes (why health probe passes)

1. **`ZEND_HAS_OOM()` + `goto fileupload_done`** throughout `main/rfc1867.c` — stop parsing; still run **`MULTIPART_EVENT_END`** when possible.
2. **`zend_handle_delayed_oom()`** after post handler (`main/SAPI.c`) — unwind vs corrupt globals where a frame exists.
3. **Session RFC1867 callback**
   - `php_rinit_session_globals()` at **`MULTIPART_EVENT_START`**
   - **`PS(in_rfc1867_update)`** + **`php_session_unserialize_init()` / incomplete-class-only** during pre-RINIT encode/decode
   - **`PG(modules_activated)`** guard — do not run progress handler during nested `request_parse_body()`
   - **`zend_delete_global_variable("_SESSION")`** at END (drop bogus incomplete-class session superglobal)
4. **`php_session_rfc1867_update/cleanup`** — check **`php_session_initialize() == FAILURE`** before flush.

`ext/session/mod_files.c` **unchanged** — lock behavior same; **correctness is “always reach unlock + session shutdown”**.

## CVE mapping (working)

| CVE | Source narrative | Lab signal |
|-----|------------------|------------|
| **109618** | OOM / bailout **corrupts runtime globals** during startup-scale work (multipart + session) | OOM on both versions; patch adds unwind + reset |
| **109619** | **Cross-request** impact: session file + handler state unsafe after OOM | **Same `PHPSESSID`**: lock + stale **`upload_progress_k`**; 8.4.27 **small POST OK** |

## Escalation hypotheses (source-driven, not proven)

1. **Session poisoning** — fixed ID + OOM leaves attacker-controlled **`upload_progress_k`** blob on disk; next request deserializes before user code (patch restricts incomplete classes during RFC1867 update).
2. **DoS** — **proven** in lab (worker lock + metadata bloat).
3. **Flag read** — still requires extra primitive (not shown in diff alone); next source targets: **`php_var_unserialize`** during `in_rfc1867_update`, **`ps_files_write` partial write + bailout**, **`php_rshutdown_session_globals`** on Apache worker reuse.

## Commands (pluto)

```bash
cd ~/Projects/telescope/php-src
git diff php-8.4.26 php-8.4.27 -- main/rfc1867.c ext/session/session.c main/SAPI.c Zend/zend_alloc.c
git show php-8.4.26:ext/session/session.c | sed -n '3200,3410p'   # old update/callback
```
