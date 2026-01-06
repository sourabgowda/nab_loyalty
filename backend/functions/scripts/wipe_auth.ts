
import * as admin from "firebase-admin";

// Initialize using default credentials (local emulator or active project)
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const auth = admin.auth();

async function main() {
    console.log("Starting Auth Wipe...");

    let nextPageToken;
    do {
        const listUsersResult = await auth.listUsers(1000, nextPageToken);
        const uids = listUsersResult.users.map((user) => user.uid);

        if (uids.length > 0) {
            console.log(`Deleting ${uids.length} users...`);
            await auth.deleteUsers(uids);
        }

        nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);

    console.log("Auth Wipe Complete.");
}

main().catch(console.error);
