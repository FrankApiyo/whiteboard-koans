<script lang="ts">
  let label = $state("Clear")

  function clear(): void {
    __blank("03: clear board")
    label = "Cleared"
  }
</script>

<button onclick={clear}>{label}</button>
