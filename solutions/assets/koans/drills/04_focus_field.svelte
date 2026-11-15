<script lang="ts">
  let field: HTMLInputElement | undefined = $state()

  $effect(() => field?.focus())
</script>

<input aria-label="Title" bind:this={field} />
