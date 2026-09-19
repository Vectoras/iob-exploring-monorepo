<script module lang="ts">
	import { defineMeta } from '@storybook/addon-svelte-csf';
	import UserCard from './UserCard.svelte';

	const { Story } = defineMeta({
		title: 'Molecules/UserCard',
		component: UserCard,
		tags: ['autodocs']
	});
</script>

<Story name="Default" args={{ user: { id: 'vectoras', name: 'Vectoras JBD' } }} />

<Story
	name="Selectable"
	args={{ user: { id: 'vectoras', name: 'Vectoras JBD' }, onselect: () => {} }}
/>
