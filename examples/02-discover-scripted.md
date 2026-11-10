# `discover` in three turns (scripted answers)

- Plugin version: 1.0.0
- Date: 2026-11-10
- Command: `/dev-harness:discover <assignment text>, then two `--continue` turns with prepared answers`
- How it was run: headless `claude -p` with `--plugin-dir`. A headless run cannot answer prompts or approve tools, so the confirmations are in the prompt and the tools are passed with `--allowedTools`. `claude -p` prints only Claude's final message, so text from earlier in the session is not shown (which is why a report can refer to something "above").
- Project: an empty git repository for a course assignment (a CSV expense summary CLI).

The answers were written in advance by the author, so this is **not** a real interactive conversation on a real idea. It shows the shape: reflect back with guesses labelled, at most three questions, three directions with one bold, the decision, then `docs/intent.md` with `status: decided` and the unanswered questions kept as open questions instead of becoming requirements.

Absolute paths were shortened (`<scratch>`, `~`). Nothing else was edited.

## Turn 1: the assignment text

```
Here is what I think this is about:

- You have a graded assignment: a small command-line tool that reads a CSV of expenses and prints a monthly summary. You can use any language.
- You have 2 weeks.
- A TA grades it on three things: **correctness, tests and a README**.
- "Bonus marks for something creative" is extra. It sits on top of the three graded items and doesn't replace them.
- "Small" and "2 weeks" tell me the rubric rewards a tight, well-checked tool over a large one.

**Guesses (not confirmed):**
- You're a student, and this is a course assignment.
- The TA will run your tool on their own CSV files, maybe with messy rows (bad dates, blank amounts, refunds). Correctness probably means handling those without crashing or giving wrong totals.
- The TA reads the README first and may never open the code. It needs to show how to install, run and test the tool in a few lines.
- You probably want a good grade without spending all 2 weeks on it. Say so if that's wrong.

I've started `docs/intent.md` with what's stated and left the rest open.

**Questions, most important first:**
1. **Language and comfort:** Which language will you use, and how comfortable are you in it? If you have no preference, I'd suggest Python, since its standard library covers CSV, dates and testing.
2. **The CSV format:** Does the course give you a sample file or a column spec, or do you design the format? Please paste any sample or rubric line you have.
3. **The "creative" bonus:** Do you want to go for it? If yes, how much extra effort will you spend: a small touch, or a real feature? If you're not sure, I'll propose options in the next step.
```


## Turn 2: the answers

```
I've updated `docs/intent.md` with your answers. Three things shape the rest of this:

- **The TA's bad-row CSV is a test of your error handling.** You can't see that file, so the tool has to cope with any kind of bad row.
- **Your goal of learning testing is a second objective.** It runs alongside the grade, and the TA will see it in the tests.
- **Standard library only** means `csv`, `datetime`, `decimal`, `argparse` and `unittest`. That's enough for everything below.

## Three directions

**A. Solid core.**
- **Pitch:** A tidy `argparse` CLI that reads the CSV, groups rows by month and category, and prints a table. Bad rows are skipped with a warning. Tests use `unittest`, and the README is clear.
- **Optimizes for:** a safe score on the three graded items.
- **Cost or risk:** Nothing sets it apart, so the bonus is unlikely. You'd also learn testing at only a basic level.
- **What the TA notices:** it works and it's tidy.

**B. Trustworthy by design (bold, my recommendation).**
- **Pitch:** The core from A, plus a tool whose answers can be checked. It ends with a "rejected rows" report giving the line number and reason for every bad row. It also checks that the totals add up: accepted rows plus rejected rows equals every row in the file.
- **Testing you'd learn:** Table-driven edge-case tests (empty file, refunds, bad dates, `0.1 + 0.2` money errors, leap days, December to January). A golden-file test for each of the 3 CSVs. A randomized test that generates a CSV with a known answer and checks the tool agrees, using a fixed seed from `random`. You'd also break the code on purpose to confirm a test fails. That is the habit that makes tests trustworthy.
- **Creative touch:** A small text bar chart per month and the change from the previous month. It's cheap, and it comes after the core is done.
- **Optimizes for:** correctness on the unseen messy CSV, test quality, and a testing skill you can reuse.
- **Cost or risk:** It takes the most time. The risk is spending the 2 weeks on tests and leaving no time for polish. I'd guard against that by building in a fixed order: core, then tests, then README, then the creative touch last. If time runs out, the creative touch is the only thing dropped.
- **What the TA notices:** the bad-row report, a test suite that clearly goes beyond the minimum, and a README with a "how it's tested" section.

**C. Creative first.**
- **Pitch:** Spend the effort on how the summary looks: budgets per category, trends, coloured output, and an export to another format.
- **Optimizes for:** the bonus marks.
- **Cost or risk:** Tests end up thin, which works against your learning goal and two of the three graded items.
- **What the TA notices:** a nice-looking output, but the unseen bad CSV is where it could lose marks.

I recommend **B**. The TA's bad-row CSV is where correctness marks are won or lost, and B is built around exactly that. It's also the only option that serves your goal of learning testing properly. The "something creative" bonus is covered by the chart and the "can't be wrong silently" design, so you don't need C's extras.

## What I still need

1. **Direction:** A, B or C, and anything you'd change. For example, B without the randomized test if that feels like too much.
2. **CSV columns:** Does the course give a column spec or a sample file? If so, paste it. If not, I'd propose `date, description, category, amount` with ISO dates (`2026-03-15`), and we'd document it in the README.
3. **Bad rows:** Is the expected behaviour specified? My default is to skip the row, report it with its line number and reason, and still print the summary for the good rows. The exit code would be non-zero only if the whole file is unusable. Tell me if the assignment says otherwise.

The success check I'd propose for B is a single command, `python -m unittest`, that passes, plus the tool running on all 3 CSVs with every bad row accounted for. I'll fix it once you've picked a direction.
```


## Turn 3: the decision

```
I've saved `docs/intent.md` with `status: decided`. Here is the final file in short:

- **Who:** You're a second-year student who knows Python and wants to learn testing properly. The TA grades correctness, tests and README, and runs 3 CSVs, one with bad rows.
- **What:** A Python CLI using only the standard library. It reads an expenses CSV and prints a monthly summary. You have 2 weeks.
- **Direction (bold, B):** The core tool, plus a rejected-rows report with a line number and reason for each bad row, and a check that accepted plus rejected rows equals every row in the file. Tests are table-driven edge cases, golden-file tests for the 3 CSVs, a seeded randomized test, and a manual "break the code and see a test fail" check. The creative touch is a text bar chart per month with the change from the previous month.
- **Build order:** core, then tests, then README, then the creative touch. If time runs short, only the creative touch is dropped.
- **Push hardest on:** bad-row handling, then test quality.
- **Out of scope:** third-party packages, the option C extras (budgets, colour, export formats), and any GUI or web interface.
- **Success check:** `python -m unittest` passes, including a test with bad rows. I also suggested running the tool on all 3 CSVs with every bad row accounted for, and breaking the logic on purpose to see a test fail. These are not confirmed yet.

**Three open questions you didn't answer.**
- **CSV format:** I assumed `date, description, category, amount` with ISO dates. Replace this with the course spec if there is one.
- **Bad-row behaviour:** I assumed skip the row, report it, and still print the summary. The exit code is non-zero only if the whole file is unusable.
- **Summary contents and submission format:** I don't know these yet. Check the assignment page or any rubric.

All three are listed under "Open questions" in the file, so none of them became a requirement. If the course spec contradicts an assumption, change it before you start coding.

Discovery is done. Next: `/dev-harness:new` to set up the project, or start building.
```


## The saved `docs/intent.md`

```
---
status: decided
updated: 2026-11-10
---

# Intent

Written by `/dev-harness:discover`. Every session reads this before planning.
Keep it short. Use the user's own words where you can.

## Who

- **User:** Second-year student, comfortable with Python, weak at testing, wants "to learn testing properly" (stated)
- **Receiver:** A TA, who runs the tool on 3 CSVs, one with bad rows (stated)
- **What the receiver cares about:** correctness, tests, a README (stated); bonus marks for "something creative" (stated)

## What

- **Deliverable:** "a small command-line tool in any language that reads a CSV of expenses and prints a monthly summary", with tests and a README (stated)
- **Deadline / budget:** 2 weeks (stated)
- **Constraints:** Python, standard library only (stated); small; CLI (stated). Submission format: <unknown>

## Why it matters

A graded assignment where the TA's hidden bad-row CSV decides correctness marks. The user also wants to come out able to write tests properly, so the test suite is both a grading item and the main thing they are learning.

## Direction chosen

- **Direction:** B, "Trustworthy by design": a core CLI that reads the CSV and prints a monthly summary, plus a rejected-rows report (line number and reason per bad row) and a check that accepted + rejected rows equals every row in the file. Tests are table-driven edge cases, golden-file tests for the 3 CSVs, a seeded randomized test against a known answer, and a manual "break the code and see a test fail" check. Creative touch: a text bar chart per month with change from the previous month.
- **Why this one:** It targets the hidden bad-row CSV and the testing goal. Accepted cost: the most time of the three options. Guard: build in a fixed order (core, tests, README, creative touch), so the creative touch is the only thing dropped if time runs short.
- **Rejected:** A (solid core): safe but nothing sets it apart and the testing stays basic. C (creative first): thin tests work against two of the three graded items and the learning goal.

## Push hardest on

1. Handling bad rows: every bad row is detected, reported with its line number and reason, never crashes the tool and never silently changes a total.
2. Test quality: tests that would actually fail if the logic broke.

## Out of scope

- Third-party packages (not allowed).
- Extras from option C: budgets, coloured output, export formats.
- A GUI or web interface.

## Success check

- `python -m unittest` passes, and it includes a test with bad rows (the user's own check).
- Proposed additions, not yet confirmed: the tool runs on all 3 CSVs with every bad row accounted for, and breaking the logic on purpose makes a test fail.

## Open questions

- CSV format: not answered. Assumed default, to be confirmed: `date, description, category, amount`, ISO dates (`2026-03-15`), documented in the README. Ask the course for a sample or spec if one exists.
- Bad-row behaviour: not answered. Assumed default, to be confirmed: skip the row, report it with line number and reason, still print the summary for the good rows, exit non-zero only if the whole file is unusable. Check the assignment text for anything that says otherwise.
- Exact contents of the "monthly summary" and the submission format are unknown. Check any rubric.
```

