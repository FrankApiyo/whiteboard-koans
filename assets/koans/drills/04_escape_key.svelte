<script lang="ts">
  interface Props {
    onescape: () => void
  }

  let { onescape }: Props = $props()

  $effect(() => {
    // >>> 04
    __blank("04: listen for escape");
    // <<< 04
  })
</script>

<p>Press Escape to clear the selection.</p>
