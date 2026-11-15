<script lang="ts">
  interface Props {
    name: string
  }

  let { name }: Props = $props()
</script>

<span>{__blank("03: badge", name)}</span>
