<script lang="ts">
  import type { Me, Person } from "../js/types"

  interface Props {
    people: readonly Person[]
    me: Me
  }

  let { people, me }: Props = $props()

  const count =
    // >>> 03
    __blank("03: count of people");
    // <<< 03
</script>

<section class="text-sm">
  <h2 class="mb-2 text-xs font-semibold text-gray-500 uppercase">{count} here</h2>
  <ul class="flex flex-col gap-1" aria-label="People on this board">
    <!-- >>> 03 -->
    {__blank("03: a row per person", "")}
    <!-- <<< 03 -->
    <!-- >>> 03 -->
    {__blank("03: just you", "")}
    <!-- <<< 03 -->
  </ul>
</section>
