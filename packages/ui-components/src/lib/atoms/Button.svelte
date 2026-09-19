<script lang="ts">
  import type { ComponentProps } from "svelte";
  import { Button } from "flowbite-svelte";

  type Props = ComponentProps<typeof Button>;

  let { children, class: className, ...rest }: Props = $props();

  const classArray = $derived([className]);
  function getClasses() {
    if (!rest.color) {
      classArray.push(
        "text-default-900 bg-default-300 hover:bg-default-400 focus-within:ring-default-200 dark:bg-default-300 dark:hover:bg-default-400 dark:focus-within:ring-default-800",
      );
    }
    return classArray;
  }
</script>

<Button class={getClasses()} {...rest}>
  {@render children?.()}
</Button>
