import { fileURLToPath } from "node:url";
import { defineConfig, includeIgnoreFile } from "eslint/config";
import js from "@eslint/js";
import ts from "typescript-eslint";
import svelte from "eslint-plugin-svelte";
import prettier from "eslint-config-prettier";
import globals from "globals";

const gitignorePath = fileURLToPath(new URL("./.gitignore", import.meta.url));

export default defineConfig(
  // Reuse .gitignore, so anything git ignores is not linted either
  includeIgnoreFile(gitignorePath),
  // Files that are tracked in git but should not be linted go here. A config
  // object with only an `ignores` key is a global ignore. Patterns are relative
  // to this file. Example (uncomment and adjust):
  // { ignores: ['apps/web/src/lib/vendor/some-file.js', 'packages/*/legacy/**'] },
  js.configs.recommended,
  ts.configs.recommended,
  svelte.configs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
  },
  {
    // Let the TypeScript parser handle <script lang="ts"> inside Svelte files
    files: ["**/*.svelte", "**/*.svelte.ts", "**/*.svelte.js"],
    languageOptions: {
      parserOptions: {
        extraFileExtensions: [".svelte"],
        parser: ts.parser,
      },
    },
  },
  // Must stay last: turns off rules that conflict with Prettier
  prettier,
  svelte.configs.prettier,
);
