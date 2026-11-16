<script lang="ts">
  interface Props {
    step?: number
  }

  let { step = 1 }: Props =
    // >>> 03
    __blank("03: step from props");
    // <<< 03

  let count =
    // >>> 03
    __blank("03: count as state");
    // <<< 03
</script>

<!-- >>> 03 -->
{__blank("03: a button that counts", "")}
<!-- <<< 03 -->
