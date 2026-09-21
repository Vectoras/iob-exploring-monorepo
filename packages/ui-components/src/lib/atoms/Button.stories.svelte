<script module lang="ts">
  import { defineMeta } from "@storybook/addon-svelte-csf";
  import Button from "./Button.svelte";

  const { Story } = defineMeta({
    title: "Atoms/Button",
    component: Button,
    tags: ["autodocs"],
    argTypes: {
      color: {
        control: "select",
        options: ["primary", "secondary", "alternative", "red", "green"],
      },
      size: { control: "select", options: ["xs", "sm", "md", "lg", "xl"] },
      disabled: { control: "boolean" },
    },
  });
</script>

<Story name="Default">
  <Button>Click me</Button>
</Story>

<Story name="Primary" args={{ color: "primary" }}>
  {#snippet template(args)}
    <Button {...args}>Click me</Button>
  {/snippet}
</Story>

<Story name="Secondary" args={{ color: "secondary" }}>
  {#snippet template(args)}
    <Button {...args}>Click me</Button>
  {/snippet}
</Story>

<Story name="Disabled" args={{ disabled: true }}>
  {#snippet template(args)}
    <Button {...args}>Can't click</Button>
  {/snippet}
</Story>
