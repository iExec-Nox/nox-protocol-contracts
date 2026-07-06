import connection from "./hardhat-connection-singleton.ts";

/**
 * Returns true when the current process was started via `hardhat run <scriptPath>`.
 * Scripts use this to run their entry function only when invoked directly, not when
 * imported as a module (e.g. from tests).
 *
 * When running `hardhat run scripts/deploy.ts`, argv looks like:
 * [ "/.../bin/node", "/.../cli.js", "run", "scripts/deploy.ts" ].
 *
 * @param scriptPath The script relative path to match against argv (e.g. "scripts/deploy.ts")
 */
export function isHardhatRunCommand(scriptPath: string): boolean {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes(scriptPath);
}

/**
 * Returns true only for a fresh local network (edr-simulated without forking).
 * Forked networks already have contracts deployed, so they should read from artifacts.
 */
export function isFreshLocalNetwork(): boolean {
    const networkConfig = connection.networkConfig;
    return networkConfig.type === "edr-simulated" && !("fork" in networkConfig);
}
