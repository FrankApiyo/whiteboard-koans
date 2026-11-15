<script lang="ts">
  interface Props {
    onescape: () => void
  }

  let { onescape }: Props = $props()

  $effect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onescape()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  })
</script>

<p>Press Escape to clear the selection.</p>
