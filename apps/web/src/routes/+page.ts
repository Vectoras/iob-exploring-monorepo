import type { PageLoad } from "./$types";
import type { User } from "@iob-exploring-monorepo/go-types";

export const load: PageLoad = async ({ fetch, depends }) => {
  depends('app:user');

  const option = (Math.round(Math.random()) * 5) + 1; // ts (1) or go (6) api
  const res = await fetch(`http://localhost:300${option}/random-user`);
  const user: User = await res.json();
  return { user };
}
