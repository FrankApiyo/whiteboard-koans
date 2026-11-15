<script lang="ts">
  // >>> course
  import { koanOnly } from "./course"
  // <<< course
  let { rows }: { rows: string[] } = $props()

  function count(): number {
    // >>> answer 05: count
    return rows.length
    // <<<
  }
</script>

<ul data-count={count()}>
  <!-- >>> answer 05: rows -->
  {#each rows as row (row)}
    <li>{row}</li>
  {/each}
  <!-- <<< -->
</ul>
