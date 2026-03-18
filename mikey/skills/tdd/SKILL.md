---
name: mikey:tdd
description: TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run without a path for an interactive TDD loop. Implements code using Functional Core / Imperative Shell design principles.
argument-hint: [path] [--plan] [--verify] [--export]
user-invocable: true
---

# Spec-Driven Development Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | File or folder containing Given/When/Then specs (triggers agent mode) |
| `--plan` | Show implementation plan only, do not write code |
| `--verify` | Run `/testify` after completion (default: auto-detect — true if testify installed, false otherwise) |
| `--export` | Save session report to `sdd-report-<timestamp>.md` |

## Description

Test-Driven Development workflow guided by Given/When/Then specifications and the embedded test philosophy.

**Two modes:**
- **Agent mode** (path provided): Reads spec files, extracts scenarios, and implements each via Red-Green-Refactor autonomously with check-ins between scenarios.
- **Interactive mode** (no path): Prompts the user to describe behaviors one at a time, implementing each through the TDD cycle with user approval.

**This skill always applies:**
1. Red-Green-Refactor TDD cycle for every scenario
2. Test philosophy: observable behavior, RITE tests, 5 Questions
3. Functional Core / Imperative Shell code design — pure logic separated from I/O
4. Minimal implementation — only write code required by the current test

**Philosophy reference:** `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
**Spec format reference:** `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md`

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (optional — file or folder of spec files)
   - `--plan` flag (plan only, do not implement)
   - `--verify` flag (run testify after completion)
   - `--export` flag (save report)

2. **Detect project conventions** by examining project files:
   - **Language and framework**: Look for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `*.csproj`, etc.
   - **Test runner**: Identify the test command (e.g., `npm test`, `pytest`, `go test`, `cargo test`, `mvn test`)
   - **Test file patterns**: Detect conventions (e.g., `*_test.go`, `test_*.py`, `*.spec.ts`, `*.test.js`, `*Test.java`)
   - **Directory structure**: Identify where tests and source files live
   - **Existing test style**: Read 1-2 existing test files to match conventions (assertion library, naming, structure)

3. **Detect testify availability**:
   - Testify is a sibling skill in this plugin: `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md`
   - Check if the testify skill file exists at that path
   - If `--verify` was not explicitly set: default to `true` if testify skill exists, `false` otherwise
   - If `--verify` was explicitly set to `true` but testify is not available: warn the user

4. **Route to mode**:
   - If `path` is provided → **Agent Mode** (Phase 2A)
   - If no `path` → **Interactive Mode** (Phase 2B)

### Phase 2A: Agent Mode (spec path provided)

#### Step 1: Parse Specs

1. If path is a file, read it
2. If path is a directory, glob for spec files: `**/*.feature`, `**/*.md`, `**/*.txt`, `**/*.spec`
3. Read the spec format reference: `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md`
4. Parse Given/When/Then scenarios from the files using the parsing rules in the reference
5. Group scenarios by feature/file

#### Step 2: Present Plan

Display a numbered list of all scenarios extracted:

```
Parsed {N} scenarios from {source}:

  1. {Feature}: {Scenario name}
     Given {precondition}
     When {action}
     Then {outcome}

  2. ...

Test location: {detected test dir}
Source location: {detected source dir}
Test runner: {detected runner}
```

If `--plan` flag is set: **STOP HERE**. Output the plan and exit.

If `--plan` is not set: Ask the user to confirm before proceeding. Use AskUserQuestion:
- "Implement all scenarios"
- "Let me pick specific scenarios"
- "Cancel"

#### Step 3: Spawn TDD Agent

Spawn a `general-purpose` agent with a prompt that includes:

1. **Role**: "You are a TDD agent. Implement features by strictly following the Red-Green-Refactor cycle for each scenario."
2. **Philosophy**: Instruct the agent to read `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` before starting
3. **Spec format**: Instruct the agent to read `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md` for parsing rules
4. **Project context** (detected in Phase 1):
   - Language/framework
   - Test runner command
   - Test file pattern
   - Source directory
   - Test directory
5. **Scenarios**: The selected scenarios, formatted as numbered Given/When/Then blocks
6. **Test naming convention** — follow RITEway principles. Each test should answer the 5 Questions structurally. When the project uses a RITEway assertion library, map Given/When/Then to RITEway's `assert()` interface:
   - `given`: the precondition (from the spec's Given clause)
   - `should`: the expected behavior (from When + Then)
   - `actual`: the actual return value
   - `expected`: the expected return value
   - Example: Given "an empty cart" / When "adding an item" / Then "cart contains 1 item" becomes `assert({ given: 'an empty cart', should: 'contain 1 item after adding', actual: cart.count(), expected: 1 })`
   - When RITEway is not available, use descriptive test names that mirror the Given/When/Then language from the spec.
7. **Execution protocol** — include this in the spawn prompt:
   - **RED**: Write a failing test for the scenario. Test observable behavior, follow RITE principles, answer the 5 Questions, match project conventions. Run tests — confirm failure.
     - Determine test type: pure logic (calculation, transformation, validation) gets a unit test with no mocks. I/O behavior (file ops, network, CLI) gets an integration test through real entry points.
   - **GREEN**: Write minimum code to pass. Apply Functional Core / Imperative Shell — pure logic in pure functions (no I/O, deterministic), I/O in thin wrapper functions. If the scenario requires both, write them as separate functions. Do NOT add code beyond what the test requires. Run tests — confirm ALL tests pass.
   - **REFACTOR**: Review for I/O mixed with logic (extract pure functions), duplication (extract only if genuinely duplicated), naming clarity, test quality (still RITE? testing behavior not implementation?). Re-run tests if changes made. If no refactoring needed, state why briefly.
   - Between scenarios, output: `Scenario {N}/{total}: {name} — {test count} tests passing`
   - After all scenarios: run full test suite, summarize tests written (unit pure / unit mocked / integration), list pure functions, I/O shells, and orchestrators created.
8. **Code design principles**: Functional Core / Imperative Shell is mandatory. Pure functions get unit tests (no mocks). I/O gets integration tests. Never mock pure functions. Max 2-3 mocks per test for unavailable external services only.
9. **Output expectations**: Show actual test output (not summaries). Show actual code written. Never fabricate test results. If a test unexpectedly fails during GREEN, debug and fix — do NOT skip.
10. **Verify instructions**:
   - If verify is enabled and testify is available: "After all scenarios are complete, the parent skill will invoke /mikey:testify for verification. No action needed from you."
   - If verify is enabled but testify is NOT available: "After all scenarios, warn the user that the testify skill was not found at `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md`."
   - If verify is disabled: "No verification step. Skip."

Wait for agent completion.

#### Step 4: Post-Completion

After the agent completes:
1. Show final test suite results
2. If `--verify` is true and testify is available: invoke `/mikey:testify` on the test directory with `--with-design`
3. If `--verify` is true but testify is NOT available: warn the user
4. If `--export`: write report (see Export section)

### Phase 2B: Interactive Mode (no spec path)

#### Step 1: Prompt for Behavior

Display:

```
Interactive TDD mode. Describe a behavior using Given/When/Then:

  Example:
    Given a list of users
    When filtering by active status
    Then only active users are returned

  (Or just describe what you want the code to do)
```

Use AskUserQuestion to get the user's input.

#### Step 2: Parse the Behavior

1. Extract Given/When/Then from the user's input
2. If the user provided a plain description instead of GWT, convert it to Given/When/Then format and confirm with the user
3. Identify what needs to be tested and where the test/source files should go

#### Step 3: RED — Write Failing Test

1. Read the philosophy: `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
2. Write a test that describes the expected behavior:
   - Test observable behavior (return values, errors), NOT implementation
   - Follow RITE principles
   - Answer the 5 Questions
   - Match the project's existing test conventions
3. Determine the right test type based on the scenario:
   - If the behavior is pure logic (calculation, transformation, validation) → **unit test, no mocks**
   - If the behavior involves I/O (file ops, network, CLI) → **integration test through real entry point**
4. Run the test suite — show the failure output
5. Confirm the test is failing for the right reason

#### Step 4: GREEN — Write Minimal Implementation

1. Write the **minimum** code to make the test pass
2. **Apply Functional Core / Imperative Shell**:
   - Extract pure logic into pure functions (no I/O, deterministic)
   - Keep I/O operations in thin shell functions
   - If the scenario involves both logic and I/O, write them as separate functions
3. Do NOT add code beyond what the test requires
4. Run the test suite — show all tests passing

#### Step 5: REFACTOR

1. Review the implementation for:
   - **I/O mixed with logic** → extract pure functions
   - **Duplication** → extract if genuinely duplicated
   - **Naming clarity** → functions and variables express intent
   - **Test quality** → still RITE? Testing behavior, not implementation?
2. If changes needed, apply them and re-run tests
3. If no refactoring needed, state why briefly

#### Step 6: Loop

After completing the cycle, ask the user:

Use AskUserQuestion:
- "Describe the next behavior"
- "Done — finish session"

If "next behavior": return to Step 1.
If "done": proceed to Post-Completion.

#### Post-Completion

1. Run the full test suite and show output
2. Summarize the session:
   - Scenarios implemented
   - Tests written (categorized: unit pure / unit mocked / integration)
   - Pure functions created, I/O shells, orchestrators
3. If `--verify` is true and testify is available: invoke `/mikey:testify` on the test directory with `--with-design`
4. If `--verify` is true but testify is NOT available: warn the user that testify skill was not found
5. If `--export`: write report (see Export section)

## Export

When `--export` is set, write a session report to `sdd-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S` for the timestamp. Include:

```markdown
# Spec-Driven Development Report

## Session Summary
- Mode: {Agent|Interactive}
- Scenarios implemented: {count}
- Total tests: {count} (unit pure: {N}, unit mocked: {N}, integration: {N})

## Scenarios

### {Scenario name}
- **Spec**: Given {X}, When {Y}, Then {Z}
- **Test**: {test file}:{line}
- **Implementation**: {source file}:{line}
- **Design**: {pure function | I/O shell | orchestrator}

## Code Design
- Pure functions created: {list with file:line}
- I/O shells: {list with file:line}
- Orchestrators: {list with file:line}

## Verification
{testify report summary or "not run"}
```

## Code Design Principles

**These principles are NOT optional.** Every implementation step must apply them:

1. **Functional Core / Imperative Shell** — Always separate pure logic from I/O
2. **Pure functions** — No side effects, deterministic, easy to unit test without mocks
3. **Thin I/O shells** — Handle only I/O (file, network, console), delegate logic to pure functions
4. **Test what you build** — Pure functions get unit tests. I/O gets integration tests. Never mock pure functions.
5. **Minimal implementation** — Only write code the current test demands. Do not anticipate future scenarios.

## Uncertainty Handling

**If the spec is ambiguous:**
- In agent mode: make a reasonable interpretation, note the assumption, continue
- In interactive mode: ask the user to clarify before writing the test

**If the test fails unexpectedly during GREEN:**
- Debug the failure
- Fix the implementation (not the test — the test defines the desired behavior)
- If the test itself was wrong, explain why and ask the user before changing it

**Never:**
- Skip a failing test
- Write implementation before the test
- Add features not described in the current scenario
- Mock pure functions
- Fabricate test results — always run the actual test command and show output

## Important Notes

- Read the philosophy at `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` before any analysis or implementation
- Read the spec format at `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md` when parsing spec files
- The TDD cycle is strict: RED (failing test) → GREEN (minimal pass) → REFACTOR. Never skip steps.
- Code design (functional core / imperative shell) is applied during GREEN and REFACTOR, not as a separate phase
- Match the project's existing conventions for test location, naming, assertion style, and file organization

## Related Documentation

- `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` — test philosophy reference
- `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md` — spec format reference
- `${CLAUDE_PLUGIN_ROOT}/skills/tdd/examples/examples.md` — example workflows
