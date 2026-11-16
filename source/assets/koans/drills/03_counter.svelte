<script lang="ts">
  interface Props {
    step?: number
  }

  let { step = 1 }: Props =
    // >>> answer 03: step from props
    $props()
    // <<<

  let count =
    // >>> answer 03: count as state
    $state(0)
    // <<<
</script>

<!-- >>> answer 03: a button that counts -->
<button type="button" onclick={() => (count += step)}>Clicked {count} times</button>
<!-- <<< -->
