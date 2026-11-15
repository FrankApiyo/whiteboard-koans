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
      <svg viewBox="0 0 12 16" width="12" height="16"><path d="M0 0 L12 9 L6 10 L3 16 Z" /></svg>
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

  .cursor {
    position: absolute;
    display: flex;
    align-items: flex-start;
    gap: 0.125rem;
    transition:
      left 50ms linear,
      top 50ms linear;
  }

  path {
    fill: var(--cursor-color);
  }

  span {
    padding: 0 0.375rem;
    border-radius: 0.25rem;
    background: var(--cursor-color);
    color: white;
    font-size: 0.75rem;
    white-space: nowrap;
  }
</style>
