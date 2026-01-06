
import * as admin from 'firebase-admin';

// Initialize
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function repairStats() {
    console.log("Starting Repair...");

    // 1. Fetch all transactions (for simplicity in this small test DB)
    const txSnaps = await db.collection("transactions").get();
    const transactions = txSnaps.docs.map(d => d.data());

    console.log(`Found ${transactions.length} transactions.`);

    // 2. Aggregate per Bunk per Day (IST)
    const stats: any = {};

    transactions.forEach((tx: any) => {
        // Calculate IST Date
        const ts = tx.timestamp.toDate(); // timestamp is Firestore Timestamp
        const istDate = new Date(ts.getTime() + (5.5 * 60 * 60 * 1000));
        const dateKey = istDate.toISOString().split('T')[0];

        const bunkId = tx.bunkId;
        const statsId = `${dateKey}_${bunkId}`;

        if (!stats[statsId]) {
            stats[statsId] = {
                id: statsId,
                bunkId: bunkId,
                date: dateKey,
                totalFuelAmount: 0,
                totalPaidAmount: 0,
                totalPointsDistributed: 0,
                totalPointsRedeemed: 0,
                transactionCount: 0,
                managers: {}
            };
        }

        const s = stats[statsId];
        const mId = tx.managerId;

        // Update Globals
        s.totalFuelAmount += (tx.fuelAmount || 0);
        s.totalPaidAmount += (tx.paidAmount || 0); // paidAmount might be diff from amount if redeemed?
        // Note: transaction.ts logic: finalAmount = paidAmount.

        s.totalPointsDistributed += (tx.points > 0 ? tx.points : 0);
        s.totalPointsRedeemed += (tx.pointsRedeemed || 0);
        s.transactionCount += 1;

        // Update Manager Stats
        if (!s.managers[mId]) {
            s.managers[mId] = {
                fuelAmount: 0,
                paidAmount: 0,
                pointsCredited: 0,
                pointsRedeemed: 0,
                txCount: 0
            };
        }

        const ms = s.managers[mId];
        ms.fuelAmount += (tx.fuelAmount || 0);
        ms.paidAmount += (tx.paidAmount || 0);
        ms.pointsCredited += (tx.points > 0 ? tx.points : 0);
        ms.pointsRedeemed += (tx.pointsRedeemed || 0);
        ms.txCount += 1;
    });

    // 3. Write to Firestore
    const batch = db.batch();

    Object.values(stats).forEach((docData: any) => {
        const ref = db.collection("bunkDailyStats").doc(docData.id);
        console.log(`Queueing update for ${docData.id}`);
        batch.set(ref, docData);
    });

    // Optional: Delete old "wrongly dated" docs if they differ?
    // For now, overwrite is fine. If ID changes (e.g. 2026-01-04 -> 2026-01-05), we might leave orphan 04 doc.
    // Let's look for docs NOT in our new set and delete them?
    const existingSnaps = await db.collection("bunkDailyStats").get();
    existingSnaps.docs.forEach(d => {
        if (!stats[d.id]) {
            console.log(`Deleting obsolete stat doc: ${d.id}`);
            batch.delete(d.ref);
        }
    });

    await batch.commit();
    console.log("Repair Complete.");
}

repairStats();
