<script module>
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import Page from './+page.svelte';

	const { Story } = defineMeta({
		title: 'Pages/Sverdle/How To Play',
		component: Page
	});
</script>

<Story name="Default" />
