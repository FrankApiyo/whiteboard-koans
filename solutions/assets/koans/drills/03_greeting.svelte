<script lang="ts">
  interface Props {
    name: string
    excited?: boolean
  }

  let { name, excited = false }: Props = $props()
</script>

<h1>Hello, {name}{excited ? "!" : "."}</h1>
