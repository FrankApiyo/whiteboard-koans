<script lang="ts">
  let { start }: { start: number } = $props()
  let count = $state(start)
</script>

<button onclick={() => (count += 1)}>{count}</button>
