
import * as admin from 'firebase-admin';

const serviceAccount = require(process.cwd() + "/serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function seedConfig() {
    console.log("Seeding Global Config...");

    // Default Configuration
    const defaultConfig = {
        pointValue: 1.0, // 1 INR = 1 Point
        creditPercentage: 2.0, // 2% points on credit
        minRedeemPoints: 100,
        maxFuelAmount: 10000,
        fuelTypes: ['Petrol', 'Diesel', 'CNG', 'Extra Premium'],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
        await db.collection("globalConfig").doc("main").set(defaultConfig);
        console.log("SUCCESS: Global Config seeded.");
        process.exit(0);
    } catch (error) {
        console.error("FAILED to seed config:", error);
        process.exit(1);
    }
}

seedConfig();
