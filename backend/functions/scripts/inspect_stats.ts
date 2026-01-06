
import * as admin from 'firebase-admin';

// Initialize
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function checkStats() {
    console.log("Checking Bunk Daily Stats...");
    const snap = await db.collection("bunkDailyStats").get();

    if (snap.empty) {
        console.log("No daily stats found.");
        return;
    }

    snap.docs.forEach(doc => {
        console.log(`ID: ${doc.id} | Data: `, JSON.stringify(doc.data(), null, 2));
    });
}

checkStats();
