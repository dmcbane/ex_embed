# Security Requirements

Findings from security review (2026-03-21) mapped to OWASP Top 10 for Web, LLMs, and Agentic AI.

## CRITICAL

### SEC-01: Path Traversal in Model Downloads
- **OWASP:** Web A03 Injection, LLM05 Supply Chain, Agentic: Inadequate Sandboxing
- **Files:** `lib/ex_embed/downloader.ex`, `lib/ex_embed/hf_client.ex`
- **Description:** `hf_repo` and `filename` values are joined into file paths without validation. A malicious registry entry containing `../` sequences could write files outside the cache directory.
- **Acceptance Criteria:**
  - All resolved download paths must be validated to reside within `cache_dir`
  - Paths containing `..` segments are rejected with `{:error, :invalid_path}`
  - Tests confirm path traversal attempts are blocked

### SEC-02: No Download Integrity Verification
- **OWASP:** LLM05 Supply Chain Vulnerabilities, Agentic: Supply Chain Compromise
- **Files:** `lib/ex_embed/downloader.ex`, `priv/registry/models.json`
- **Description:** Downloaded ONNX models and tokenizer files are never verified against checksums. MITM or compromised mirrors could serve malicious models.
- **Acceptance Criteria:**
  - Registry entries include SHA256 checksums for model files
  - Downloaded files are verified against expected checksums
  - Verification failures delete the file and return `{:error, :checksum_mismatch}`
  - Existing files with wrong checksums trigger re-download

## HIGH

### SEC-03: Sensitive Information in Error Messages
- **OWASP:** Web A09 Security Logging and Monitoring Failures
- **Files:** `lib/ex_embed/cache.ex`, `lib/ex_embed/serving.ex`, `lib/ex_embed/pipeline.ex`
- **Description:** `Exception.message(e)` and `inspect(reason)` in error tuples expose file paths, internal state, and library details to callers.
- **Acceptance Criteria:**
  - Error tuples returned to callers contain only generic atoms (e.g., `:model_load_failed`)
  - Full exception details logged at `:debug` level only
  - No system paths appear in `:info` or `:warning` level logs

### SEC-04: HF_TOKEN Leakage Risk
- **OWASP:** Web A02 Cryptographic Failures, Web A07 Identification and Authentication Failures
- **Files:** `lib/ex_embed/hf_client.ex`
- **Description:** The HF_TOKEN Bearer token is placed in HTTP headers. If Req errors are inspected or logged, the token value could appear in output.
- **Acceptance Criteria:**
  - Req errors are caught and re-wrapped without exposing headers
  - Token value never appears in any log output or error tuple
  - Basic token format validation rejects obviously malformed values

## MEDIUM

### SEC-05: No URL Encoding in HFClient
- **OWASP:** Web A03 Injection
- **Files:** `lib/ex_embed/hf_client.ex`
- **Description:** `hf_repo` and `filename` are interpolated directly into URLs without encoding. Special characters could alter query parameters.

### SEC-06: Unsafe File.mkdir_p! in HFClient
- **Files:** `lib/ex_embed/hf_client.ex`
- **Description:** `File.mkdir_p!` crashes on failure instead of returning an error tuple.

### SEC-07: No Resource Limits
- **OWASP:** LLM04 Model DoS, Agentic: Unbounded Resource Consumption
- **Files:** `lib/ex_embed/cache.ex`
- **Description:** No limits on number of cached models in memory or download sizes.

### SEC-08: No cache_dir Validation
- **OWASP:** Agentic: Inadequate Sandboxing
- **Files:** `lib/ex_embed/downloader.ex`
- **Description:** Configured `cache_dir` used without checking it exists, has correct permissions, or is a symlink.

## LOW

### SEC-09: System Paths in Log Output
- **Files:** `lib/ex_embed/downloader.ex`
- **Description:** Debug logs expose internal cache directory paths.

### SEC-10: No Network Timeouts
- **Files:** `lib/ex_embed/hf_client.ex`
- **Description:** `Req.get` calls have no explicit timeouts. Large model downloads could hang indefinitely.

## INFO

### SEC-11: Registry JSON Uses Atom Keys
- **Files:** `lib/ex_embed/registry.ex`
- **Description:** `Jason.decode!(keys: :atoms)` creates atoms from JSON. Low risk since file is vendored, but atom table exhaustion possible if file were dynamically generated.

### SEC-12: NIF Dependencies
- **Files:** `mix.exs`
- **Description:** `ortex` and `tokenizers` are Rust NIFs. Bugs in NIF code can crash the BEAM VM. Keep updated.
