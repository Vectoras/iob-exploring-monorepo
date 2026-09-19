<script lang="ts">
  import { Card } from "flowbite-svelte";
  import type { User } from "@iob-exploring-monorepo/go-types";
  import Button from "../atoms/Button.svelte";

  type Props = {
    user: User;
    onselect?: (user: User) => void;
  };

  let { user, onselect }: Props = $props();
</script>

<Card class="p-4">
  <h5 class="text-xl font-bold text-gray-900 dark:text-white">{user.name}</h5>
  <p class="text-sm text-gray-500 dark:text-gray-400">@{user.id}</p>
  {#if onselect}
    <Button class="mt-3" size="sm" onclick={() => onselect(user)}>Select</Button
    >
  {/if}
</Card>
