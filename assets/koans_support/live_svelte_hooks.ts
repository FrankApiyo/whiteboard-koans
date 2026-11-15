// live_svelte's package entry is TypeScript source that fails svelte-check; this path reaches the
// hook module, typed by its own .d.ts, without pulling that entry into the program.
export { getHooks } from "../../node_modules/live_svelte/assets/js/live_svelte/hooks.svelte.js"
