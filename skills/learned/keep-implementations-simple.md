# Keep Implementations Simple and Efficient

**Extracted:** 2026-04-17
**Context:** Applies to all implementation tasks, especially when adding conventions, annotations, or cross-cutting concerns to code.

## Problem

When asked to implement a convention or requirement, there is a temptation to use the most "correct" or "complete" technical solution (e.g., adding `google.api.http` option annotations + external dependencies to document REST paths in proto files). This adds unnecessary complexity when a simpler approach (comments) satisfies the requirement just as well.

## Solution

Default to the simplest implementation that satisfies the stated requirement. Do not add:
- External dependencies unless explicitly needed
- Framework-level constructs (annotations, decorators, options) when documentation suffices
- Abstraction layers for hypothetical future needs

If the user wants more complexity, they will say so.

## Example

**Requirement:** "All endpoints must start with /config. Update proto files."

**Over-engineered (wrong):**
```protobuf
import "google/api/annotations.proto"; // new external dep

rpc ListAccounts(...) returns (...) {
  option (google.api.http) = {     // complex option structure
    get: "/config/store/accounts"
  };
}
```

**Simple (correct):**
```protobuf
// GET /config/store/accounts
rpc ListAccounts(...) returns (...);
```

## When to Use

Every time. Before choosing an implementation approach, ask: "Is there a simpler way that satisfies the requirement?" If yes, use it. Reserve complexity for when the user explicitly requests it or the simpler approach provably cannot work.
