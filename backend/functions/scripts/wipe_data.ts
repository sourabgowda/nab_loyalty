
import * as admin from "firebase-admin";

// Initialize using default credentials (local emulator or active project)
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function deleteCollection(collectionPath: string, batchSize: number = 50) {
    const collectionRef = db.collection(collectionPath);
    const query = collectionRef.orderBy('__name__').limit(batchSize);

    return new Promise((resolve, reject) => {
        deleteQueryBatch(db, query, resolve).catch(reject);
    });
}

async function deleteQueryBatch(db: FirebaseFirestore.Firestore, query: FirebaseFirestore.Query, resolve: Function) {
    const snapshot = await query.get();

    const batchSize = snapshot.size;
    if (batchSize === 0) {
        // When there are no documents left, we are done
        resolve();
        return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    process.stdout.write(`Deleted ${batchSize} docs from query.\n`);

    // Recurse on the next process tick, to avoid
    // exploding the stack.
    process.nextTick(() => {
        deleteQueryBatch(db, query, resolve);
    });
}

async function main() {
    console.log("Starting DB Cleanup...");

    console.log("Deleting 'auditLogs'...");
    await deleteCollection("auditLogs");

    console.log("Deleting 'transactions'...");
    await deleteCollection("transactions");

    console.log("Deleting 'users'...");
    await deleteCollection("users");

    console.log("Deleting 'bunks'...");
    await deleteCollection("bunks");

    console.log("Deleting 'globalConfig'...");
    await deleteCollection("globalConfig");

    console.log("Deleting 'bunkDailyStats'...");
    await deleteCollection("bunkDailyStats");

    console.log("Cleanup Complete.");
}

main().catch(console.error);
