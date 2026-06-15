import simpleImportSort from "eslint-plugin-simple-import-sort";
import tseslint from "typescript-eslint";

export default tseslint.config(
    { ignores: ["node_modules/**", "artifacts/**", "cache/**", "coverage/**", "ignition/deployments/**"] },
    {
        files: ["**/*.ts"],
        extends: [tseslint.configs.recommended],
        plugins: { "simple-import-sort": simpleImportSort },
        rules: {
            // "^\\u0000"    side-effect imports (import "foo")
            // "^node:"      Node builtins (node:fs, node:path)
            // "^@?\\w"      npm packages (@openzeppelin/..., hardhat, ethers)
            // "^"           absolute + relative imports (./foo, ../bar, src/foo)
            "simple-import-sort/imports": ["error", { groups: [["^\\u0000", "^node:", "^@?\\w", "^"]] }],
            "simple-import-sort/exports": "error",
        },
        languageOptions: {
            parserOptions: {
                projectService: true,
                tsconfigRootDir: import.meta.dirname,
            },
        },
    },
);
