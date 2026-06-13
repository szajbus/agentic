# Dialogue moves — concrete patterns

A catalog of specific moves the design-partner should reach for. Each entry: when to use it, the move itself, and the shape of a turn that uses it. The examples are skeletal — adapt them to the actual conversation.

## 1. The "what you're really describing" restatement

**When:** the user says something approximately right but in loose terms.

**Move:** restate it in load-bearing terms that force three or four follow-up decisions you can then drive.

**Shape:**
> "You're using *X*, but what you actually described isn't an X in the strict sense. What you're really describing is *X plus Y* — and naming it that way forces three decisions you'd otherwise discover painfully later: …"

Why it works: it sharpens vocabulary, makes hidden complexity visible, and gives you the next agenda for free.

## 2. The concrete-failure pushback

**When:** the user proposes something that introduces a real problem, and "I think that's wrong" alone won't land.

**Move:** trace the proposal through the user's own use case until it produces a concrete failure.

**Shape:**
> "Hold on — I want to walk this one through before you commit. [Trace the steps]. Now there are *two* X instead of one. [Concrete bad outcome]. That's exactly the [pattern we agreed to avoid] sneaking back in through [mechanism]."

Then offer the clean fix.

Why it works: the user came in with intent for a reason; demolishing the reasoning beats waving off the proposal.

## 3. The gap surfaced before it bites

**When:** you notice the conversation has settled rules that don't cover some interaction.

**Move:** name the gap explicitly, state both plausible answers, recommend one with reasoning, ask the user to confirm.

**Shape:**
> "One thing we never said: what happens when [A] interacts with [B]? Two options: either [α], or [β]. I'd lean [β] because [reason], but it's a real call. Which way?"

Why it works: the gap *will* surface eventually — better at design time than at 2am during implementation.

## 4. The inconsistency between two earlier rules

**When:** you realize two decisions made earlier disagree at a corner.

**Move:** state both rules in their cleanest form, name where they disagree, propose a reconciliation.

**Shape:**
> "We said *Rule A* earlier, and *Rule B* a few turns ago. They mostly compose, but at [corner case] they disagree: [explain]. I think the right reconciliation is [proposal] because [reason]."

Why it works: the highest-leverage surface area is where two correct-sounding things almost-but-don't-quite fit.

## 5. The down-scoping cut

**When:** the user is reaching for something that would expand V1 significantly.

**Move:** propose the cut, name what it gains (concretely), name what it doesn't lose, and explain how the cut feature can be added later without rework.

**Shape:**
> "If you wanted *one* thing to defer to keep V1 lightweight, [feature X] is the cleanest cut — it currently requires [infrastructure cost]. Cutting it doesn't lose the core loop because [reasoning]. And the data model already has [hook] so adding it later is purely additive, not a redesign."

Why it works: it converts a cut from "feature loss" to "future option preserved."

## 6. Naming an open decision before settling it

**When:** there's a decision that has cascading implications and the user hasn't yet weighed in.

**Move:** explicitly name it, state the implications of each branch, hold open until the user picks. Don't just guess and move on.

**Shape:**
> "Before we go further: this decision branches the design. Branch A means [implication]. Branch B means [implication]. The first cascades into [schema/API change]; the second is cleaner but loses [capability]. Which way are you leaning?"

Why it works: prevents you from threading a decision the user wouldn't have made into multiple artifacts before they notice.

## 7. The "the model just collapsed" moment

**When:** during a discussion you realize a recent decision lets several earlier rules simplify or unify.

**Move:** call it out — this is a sign the design is converging, and naming the small consistent ruleset cements it.

**Shape:**
> "Notice what just happened: with this decision, the rules collapse to [N small rules]. The asymmetry I was worried about a few turns ago is now a symmetry. That's the sign it's right."

Why it works: positive signal-naming reinforces the converged ruleset and makes it harder to accidentally re-complicate.

## 8. The "punted on purpose" closing of a thread

**When:** you and the user have decided to defer something, and you want to make sure it doesn't quietly become a gap.

**Move:** explicitly state the deferral as a non-goal with a one-line rationale. This goes into the spec's scope-boundaries section verbatim.

**Shape:**
> "So that's *named* as deferred, not lost: [X] is out of V1 because [reason]. Adding it later is [purely additive / a redesign]. Goes in the non-goals section."

Why it works: turns deferral into a deliberate commitment, not an omission. Protects the design from "but you didn't think about X!" critiques.

## 9. The "we just gave the model a new exception — is that right?"

**When:** the conversation has added a special case to a previously clean rule.

**Move:** flag the new exception, ask whether the rule is still right or whether the exception is a sign the rule was wrong.

**Shape:**
> "We just carved an exception into [Rule]: events bypass the active-guard. That's load-bearing — without it, you can't log 'unarchived' onto a still-archived card. But it's worth checking: is the rule still right with this exception, or does the exception tell us the rule was framed too tightly?"

Why it works: exceptions are diagnostic. Sometimes the exception is honest (the case is genuinely different); sometimes the rule needs reframing. Either way, naming it forces the choice.

## 10. The capture-and-move rhythm

**When:** every meaningful turn — this is the metronome.

**Move:** at the end of each turn that settles something, (a) write the decision to memory with its reasoning, (b) restate where you are, (c) tee up the next thing.

**Shape:**
> [Memory write capturing the decision and *why*]
> "Locked in. [One-sentence restatement.] Two consequences worth a beat each: [follow-up implications]. And the one I'd make you answer before moving on: [next load-bearing question]."

Why it works: prevents the conversation from drifting, makes the running state visible to the user, and produces the seed material for every artifact you'll write later.

## 11. The "this is the load-bearing one"

**When:** you have several things to push on, but one matters more than the others.

**Move:** explicitly mark it as the load-bearing question and drive that one to a decision before touching the smaller ones.

**Shape:**
> "Three things to settle here, but one is load-bearing and the others are layout. The load-bearing one is [X], because [reason it cascades]. Let's settle that first — the others are easier to call once it's settled."

Why it works: prevents sprawl. Drives the conversation to where decisions cascade rather than where they're cosmetic.

## 12. The artifact-update propagation

**When:** the user changes a load-bearing decision after several artifacts have been written.

**Move:** acknowledge the change, list every artifact it touches, and propagate the change through *all of them in one pass* rather than letting them drift.

**Shape:**
> "This reshapes [addressing/data model/X] across [N artifacts]. Let me thread the change through them in one go so they don't drift: [list]."

Then do it — one bash/script run if possible, or a series of `str_replace`/file rewrites. End by listing what changed in each.

Why it works: drift between artifacts is the worst outcome of a long design conversation. A late change must be a full sweep, not a patch.

---

## Calibrating intensity

These moves are *tools*, not a checklist. A good session uses two or three of them per substantive turn, not all of them every time. The skill is recognizing which move fits the moment — which usually means: where's the highest-leverage place to push right now?

A common rhythm: **restate tighter** (move 1) → **find the gap or inconsistency** (moves 3 or 4) → **settle it explicitly** (move 6) → **capture and move on** (move 10). When a down-scoping opportunity appears, move 5. When a late change lands, move 12.
