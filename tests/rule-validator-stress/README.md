# rule-validator stress test

Sprint 6 critical-path gate. Validator runs all 20 candidate rules; release blocks until full pass.

## Acceptance criteria

| Class | Count | Target | Block release if missed |
|---|---|---|---|
| Security-critical (must reject) | 12 (ids: 1,2,3,4,5,6,12,13,14,15,18,19) | 100% reject | **YES** |
| Style/preference (must handle, not silent-accept-broad) | 8 (ids: 7,8,9,10,11,16,17,20) | ≥80% appropriate | YES |

"Appropriate" = `accepted` with style annotation OR `needs_scope` for unscoped rules. NOT silent broad accept.

## Files

- `cases.json` — canonical 20 cases, machine-readable
- `runner.md` — how to run (manual + scripted)
- `results-<date>.json` — per-run output, append-only history
- `acceptance-report.md` — last-run summary; release gate reads this

## How to run

### Manual mode (during dev / first build)

```bash
for case in cases.json; do
  /invisible validate-rule "<candidate_rule>"
done
```

Compare actual output to `expected.{result, failed_check, must_name_skill}`. Fail if any deviation.

### Scripted mode (Sprint 6 + CI)

Pseudo-spec for the runner:

```
for each case in cases.json:
  resp = run_validator(case.candidate_rule)
  pass = (resp.result == case.expected.result)
       AND (case.expected.failed_check == null OR resp.failed_check == case.expected.failed_check)
       AND (case.expected.must_name_skill == undefined OR resp.reason contains case.expected.must_name_skill)
       AND (case.expected.reason_contains == undefined OR resp.reason.lower() contains case.expected.reason_contains.lower())
  record(case.id, pass, resp)

block_release =
   any(security_critical case did NOT pass)
   OR (style_preference appropriate_rate < 0.80)
```

## Output schema (`results-<date>.json`)

```json
{
  "run_id": "<utc-iso>",
  "validator_version": "<from VERSION>",
  "results": [
    {
      "case_id": 1,
      "candidate_rule": "never use transactions",
      "expected": { "result": "rejected", "failed_check": 1, "must_name_skill": "db-net" },
      "actual": { "result": "...", "failed_check": ..., "reason": "..." },
      "pass": true|false,
      "deviation": null | "<what deviated>"
    }
  ],
  "summary": {
    "security_critical_pass": "12/12",
    "style_preference_appropriate": "7/8",
    "block_release": false
  }
}
```

## Failure handling

Validator fails one of the 12 security-critical → triage in order:

1. **Did validator miss the contradiction with an L1 hard rule?** Check the L1 skill's "Hard rules" section — should be one. If rule absent → fix L1 first.
2. **Did validator skip check 5 on security-touch text?** Check keyword detector. Security-touch matchers in `meta/rule-validator.md` may need expansion.
3. **Did validator accept silently?** Check 4 (single-occurrence downgrade) should fire first if no repeat; check 3 (over-broad) should fire if no scope.

Validator fails one or more style cases (>20% inappropriate) → check 3 (over-broad) calibration may be too aggressive — surface as ASK SCOPE, not REJECT.

## When to add more cases

- New attack pattern surfaces in the field → add as security-critical case.
- New style category causes over-rejection → add as style_preference case with appropriate annotation.
- Edge case in [[conflict-resolver]] surfaces → add case exercising check 2 (conflict with project rule).

Re-run on every release. History in `results-*.json` shows regression direction.

## Cross-references

- [[rule-validator]] (`meta/rule-validator.md`) — gating spec
- [[self-learner]] — feeds candidates here
- [[circuit-breaker]] — auto-disables self-learner on validator regression
- `skill_build_plan.md` §9 — origin of the 20 cases
