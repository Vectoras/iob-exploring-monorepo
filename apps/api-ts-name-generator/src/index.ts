import Fastify from "fastify";
import {
  uniqueNamesGenerator,
  adjectives,
  colors,
  animals,
} from "unique-names-generator";
import type { User } from "types";

const fastify = Fastify({ logger: true });

fastify.get("/random-user", async (): Promise<User> => {
  const name = uniqueNamesGenerator({
    dictionaries: [adjectives, colors, animals],
    separator: "-",
    style: "lowerCase",
  });

  return {
    id: crypto.randomUUID(),
    name,
  };
});

const start = async () => {
  try {
    await fastify.listen({ port: 3001 });
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
