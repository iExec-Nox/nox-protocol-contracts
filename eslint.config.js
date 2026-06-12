import simpleImportSort from "eslint-plugin-simple-import-sort";
import tseslint from "typescript-eslint";

export default tseslint.config(
    { ignores: ["node_modules/**", "artifacts/**", "cache/**", "coverage/**", "ignition/deployments/**"] },
    {
        files: ["**/*.ts"],
        extends: [tseslint.configs.recommended],
        plugins: { "simple-import-sort": simpleImportSort },
        rules: {
            "simple-import-sort/imports": "error",
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
