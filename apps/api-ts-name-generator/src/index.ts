import Fastify from "fastify";
import cors from "@fastify/cors";
import { uniqueNamesGenerator, adjectives, animals, names } from "unique-names-generator";
import type { User } from "types";

const fastify = Fastify({ logger: true });

await fastify.register(cors, {
  origin: "http://localhost:5173",
});

fastify.get("/random-user", async (): Promise<User> => {
  const name = uniqueNamesGenerator({
    dictionaries: [adjectives, animals],
    separator: " ",
    style: "capital",
  });
  const nickname = uniqueNamesGenerator({
    dictionaries: [names],
    style: "capital"
  });

  return {
    id: crypto.randomUUID(),
    name,
    nickname
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
