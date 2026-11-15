<script lang="ts">
  import { untrack } from "svelte"

  interface Props {
    initial: string
  }

  let { initial }: Props = $props()

  let name = $state(untrack(() => initial))
</script>

<!-- >>> 04 -->
{__blank("04: bind the name", "")}
<!-- <<< 04 -->
<p>Hello, {name}</p>
<button type="button" onclick={() => (name = "")}>Clear</button>
