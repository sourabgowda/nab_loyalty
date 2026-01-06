
import * as admin from 'firebase-admin';

// Initialize
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function debugQuery() {
    console.log("=== Debugging Analytics Query ===");

    const inputDate = "2026-01-05";
    console.log(`Input Date string: "${inputDate}"`);

    // Simulate Backend Logic
    const targetDate = new Date(inputDate);
    console.log(`Parsed Date object: ${targetDate.toISOString()}`);

    const startDateStr = targetDate.toISOString().split('T')[0];
    const endDateStr = startDateStr;

    console.log(`Query Range: [${startDateStr}] to [${endDateStr}]`);

    const query = db.collection("bunkDailyStats")
        .where("date", ">=", startDateStr)
        .where("date", "<=", endDateStr);

    const snap = await query.get();

    console.log(`Query returned ${snap.size} documents.`);

    if (snap.empty) {
        console.log("NO MATCHES FOUND. Dumping all docs to compare:");
        const all = await db.collection("bunkDailyStats").get();
        all.docs.forEach(d => {
            console.log(`- DocID: ${d.id}, DateField: "${d.data().date}"`);
        });
    } else {
        snap.docs.forEach(d => {
            console.log(`+ Found: ${d.id}, Data: ${JSON.stringify(d.data().managers)}`);
        });
    }
}

debugQuery();
