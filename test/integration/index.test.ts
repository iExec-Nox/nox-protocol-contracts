// Integration test entry point.
// Imports all integration test files so they run in a single worker (serial).
// This prevents race conditions on the CreateX factory pre-signed deployment transaction.
import "./ConfidentialTokenMock.test.ts";
import "./NoxComputeIT.test.ts";
import "./Upgrade.test.ts";
