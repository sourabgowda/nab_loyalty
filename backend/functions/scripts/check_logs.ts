
import * as admin from 'firebase-admin';

// Initialize
const serviceAccount = require("../serviceAccount.json");
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();

async function checkCloudLog() {
    console.log("No direct way to tail Cloud Logs from here without gcloud CLI.");
    console.log("Assuming user will check Dashboard or console.");
}

checkCloudLog();
