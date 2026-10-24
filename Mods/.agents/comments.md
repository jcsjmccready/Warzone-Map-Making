# Comments

- A comment survives only if it states a single short fact needed to read *this* line/field/function/block
  correctly, right now. Nothing beyond that.
- No "why we chose this over that," no debugging/bug-history provenance, no "this used to be X," no
  description of a consequence/implication beyond the bare fact itself. If it's about *past reasoning*
  rather than a *current constraint*, cut it - even when it's true and non-obvious.
- No cross-references to other functions/files unless a critical issue (`see X`). A comment must stand alone or not exist.
- Function/class header comments are allowed, but must be a single short clause, not a paragraph. If
  an explanation needs more than one short sentence, that's a signal to either cut it down to the one
  essential fact, or move it to a short *trailing* inline comment at the exact line it concerns, rather
  than a block comment at the top.
- `@field`/`@param`/`@return` doc comments are allowed and should stay terse - a short phrase, not a
  format spec or provenance explanation.
- The one thing worth keeping: a comment that changes how a reader should classify/scope future code
  here (e.g. "this exists because the mod no longer receives updates" - a forward-looking scope
  definition), as opposed to one that justifies how the existing code got written.
- This rule is for code comments only. `ModDescription.txt` and other user-facing prose docs are held
  to the opposite standard - prefer accuracy and completeness there, don't cut them for brevity.
