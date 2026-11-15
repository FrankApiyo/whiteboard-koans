<script lang="ts">
  interface Props {
    step?: number
  }

  let { step = 1 }: Props = $props()

  let count =
    $state(0)
</script>

<button type="button" onclick={() => (count += step)}>Clicked {count} times</button>
