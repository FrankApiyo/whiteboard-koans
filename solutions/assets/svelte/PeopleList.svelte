<script lang="ts">
  import type { Me, Person } from "../js/types"

  interface Props {
    people: readonly Person[]
    me: Me
  }

  let { people, me }: Props = $props()

  const count = $derived(Math.max(people.length, 1))
</script>

<section class="people">
  <h2>{count} here</h2>
  <ul aria-label="People on this board">
    {#each people as person (person.tab)}
      <li>
        <span class="dot" data-color={person.color} style:background-color={person.color}></span>
        {person.name}{#if person.tab === me.tab}{" (you)"}{/if}
      </li>
    {:else}
      <li>
        <span class="dot" data-color={me.color} style:background-color={me.color}></span>
        {me.name}{" (you)"}
      </li>
    {/each}
  </ul>
</section>

<style>
  .people {
    font-size: 0.875rem;
  }

  h2 {
    margin: 0 0 0.5rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    color: #6b7280;
  }

  ul {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .dot {
    display: inline-block;
    width: 0.625rem;
    height: 0.625rem;
    margin-right: 0.375rem;
    border-radius: 9999px;
  }
</style>
