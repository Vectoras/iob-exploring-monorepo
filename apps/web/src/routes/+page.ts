import type { PageLoad } from "./$types";
import type { User } from "types";

export const load: PageLoad = async ({ fetch }) => {
  const res = await fetch('http://localhost:3001/random-user');
  const user: User = await res.json();
  return { user };
}
