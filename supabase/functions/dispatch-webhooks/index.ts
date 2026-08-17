import { handler } from './handler.ts'

// The entry point, and nothing else. Everything testable is in `handler.ts`,
// because importing a module that calls `Deno.serve` at top level starts a
// server in whatever imports it — including a test.
Deno.serve(handler)
