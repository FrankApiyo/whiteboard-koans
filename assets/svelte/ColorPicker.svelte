<script lang="ts">
  import type { Color } from "../js/types"

  interface Props {
    colors: readonly Color[]
    value: Color
    onpick: (color: Color) => void
  }

  let { colors, value, onpick }: Props = $props()
</script>

<fieldset class="picker">
  <legend class="sr-only">Colour</legend>
  {#each colors as color (color)}
    <label class="swatch" style:--swatch={color}>
      <input
        type="radio"
        name="colour"
        value={color}
        checked={color === value}
        onchange={() => onpick(color)}
      />
      <span class="sr-only">{color}</span>
    </label>
  {/each}
</fieldset>

<style>
  .picker {
    display: flex;
    gap: 0.25rem;
    border: 0;
    margin: 0;
    padding: 0;
  }

  .swatch {
    width: 1.75rem;
    height: 1.75rem;
    border-radius: 9999px;
    background: var(--swatch);
    cursor: pointer;
  }

  .swatch:has(input:checked) {
    outline: 3px solid #212529;
    outline-offset: 2px;
  }

  .swatch:has(input:focus-visible) {
    outline: 3px solid #1971c2;
    outline-offset: 2px;
  }

  input {
    position: absolute;
    opacity: 0;
    pointer-events: none;
  }
</style>
