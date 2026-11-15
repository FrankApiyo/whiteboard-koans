<script lang="ts">
  import { untrack } from "svelte"

  interface Props {
    initial: string
  }

  let { initial }: Props = $props()

  let name = $state(untrack(() => initial))
</script>

<input aria-label="Name" bind:value={name} />
<p>Hello, {name}</p>
<button type="button" onclick={() => (name = "")}>Clear</button>
