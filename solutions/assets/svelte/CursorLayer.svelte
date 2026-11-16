<script lang="ts">
  import { pruneCursors, type Cursors } from "../js/cursors"
  import { BOARD_HEIGHT, BOARD_WIDTH, type Person } from "../js/types"

  interface Props {
    cursors: Cursors
    people: readonly Person[]
  }

  let { cursors, people }: Props = $props()

  const visible = $derived([...pruneCursors(cursors, people).values()])

  const percent = (value: number, size: number) => `${(value / size) * 100}%`
</script>

<div class="layer" aria-hidden="true">
  {#each visible as cursor (cursor.tab)}
    <div
      class="cursor"
      data-tab={cursor.tab}
      style:left={percent(cursor.x, BOARD_WIDTH)}
      style:top={percent(cursor.y, BOARD_HEIGHT)}
      style:--cursor-color={cursor.color}
    >
      <span>{cursor.name}</span>
    </div>
  {/each}
</div>

<style>
  .layer {
    position: absolute;
    inset: 0;
    overflow: hidden;
    pointer-events: none;
  }

  .layer :global(.cursor) {
    position: absolute;
    display: flex;
    align-items: flex-start;
    gap: 0.125rem;
  }

  @media (prefers-reduced-motion: no-preference) {
    .layer :global(.cursor) {
      transition:
        left 50ms linear,
        top 50ms linear;
    }
  }

  .layer :global(.cursor::before) {
    content: "";
    flex: none;
    width: 12px;
    height: 16px;
    background: var(--cursor-color);
    clip-path: polygon(0 0, 100% 56.25%, 50% 62.5%, 25% 100%);
  }

  .layer :global(.cursor span) {
    padding: 0 0.375rem;
    border-radius: 0.25rem;
    background: var(--cursor-color);
    color: white;
    /* Black on palette colours lighter than oklch L 0.605 (orange, yellow, green, teal), white
       on the rest: at least 4.5:1 on every one. */
    color: oklch(from var(--cursor-color) clamp(0, (0.605 - l) * 1000, 1) 0 0);
    font-size: 0.75rem;
    white-space: nowrap;
  }
</style>
