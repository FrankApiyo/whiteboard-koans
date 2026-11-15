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
  <!-- >>> 12 -->
  {__blank("12: a labelled cursor per tab", "")}
  <!-- <<< 12 -->
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
    transition:
      left 50ms linear,
      top 50ms linear;
  }

  .layer :global(.cursor::before) {
    content: "";
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
    font-size: 0.75rem;
    white-space: nowrap;
  }
</style>
