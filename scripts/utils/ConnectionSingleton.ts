// create a singleton class with connection to be used across scripts

import hre from "hardhat";
import { NetworkConnection } from "hardhat/types/network";

/**
 * Hardhat 3 creates a new NetworkConnection instance on each call to hre.network.connect()
 * when working with "edr-simulated" networks. This leads to issues when trying to share the
 * same state across different scripts or tests.
 * This ConnectionSingleton class ensures that only one instance of NetworkConnection
 * is created and shared across deployment scripts and tests.
 */
class ConnectionSingleton {
    private _instance!: NetworkConnection;

    async getInstance() {
        if (!this._instance) {
            this._instance = await hre.network.connect();
        }
        return this._instance;
    }
}

const connection = await new ConnectionSingleton().getInstance();
export default connection;
