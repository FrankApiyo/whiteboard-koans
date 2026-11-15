<script lang="ts">
  import type { Color } from "../js/types"

  interface Props {
    colors: readonly Color[]
    value: Color
    onpick: (color: Color) => void
  }

  let { colors, value, onpick }: Props = $props()

  const group = $props.id()
</script>

<fieldset class="flex gap-1">
  <legend class="sr-only">Colour</legend>
  {#each colors as color (color)}
    <span
      class="relative size-7 rounded-full outline-offset-2 has-checked:outline-3 has-checked:outline-[#212529] has-focus-visible:outline-3 has-focus-visible:outline-[#1971c2]"
      style:background-color={color}
    >
      <input
        type="radio"
        class="absolute inset-0 size-full cursor-pointer appearance-none opacity-0"
        aria-label={color}
        name={group}
        value={color}
        checked={color === value}
        onchange={() => onpick(color)}
      />
    </span>
  {/each}
</fieldset>
