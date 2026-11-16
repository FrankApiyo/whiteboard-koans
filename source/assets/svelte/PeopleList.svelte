<script lang="ts">
  import type { Me, Person } from "../js/types"

  interface Props {
    people: readonly Person[]
    me: Me
  }

  let { people, me }: Props = $props()

  const count =
    // >>> answer 03: count of people
    $derived(Math.max(people.length, 1))
    // <<<
</script>

<section class="text-sm">
  <h2 class="mb-2 text-xs font-semibold text-base-content/70 uppercase">{count} here</h2>
  <ul class="flex flex-col gap-1" aria-label="People on this board">
    <!-- >>> answer 03: a row per person -->
    {#each people as person (person.tab)}
      <li>
        <span
          class="mr-1.5 inline-block size-2.5 rounded-full"
          data-color={person.color}
          style:background-color={person.color}
        ></span>
        {person.name}{#if person.tab === me.tab}{" (you)"}{/if}
      </li>
    {/each}
    <!-- <<< -->
    <!-- >>> answer 03: just you -->
    {#if people.length === 0}
      <li>
        <span
          class="mr-1.5 inline-block size-2.5 rounded-full"
          data-color={me.color}
          style:background-color={me.color}
        ></span>
        {me.name}{" (you)"}
      </li>
    {/if}
    <!-- <<< -->
  </ul>
</section>
