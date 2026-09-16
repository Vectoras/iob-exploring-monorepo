<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Page from './+page.svelte';

	const { Story } = defineMeta({
		title: 'Pages/About',
		component: Page
	});
</script>

<Story name="Default" />
