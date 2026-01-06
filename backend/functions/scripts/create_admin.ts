import * as admin from 'firebase-admin';

// Initialize Firebase Admin
const serviceAccount = require(process.cwd() + "/serviceAccount.json"); // Ensure path is correct relative to execution CWD
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

const db = admin.firestore();
const auth = admin.auth();

async function createAdmin(phoneNumber: string) {
    if (!phoneNumber) {
        console.error("Error: Phone number argument required.");
        console.error("Usage: npm run create-admin -- <phone_number>");
        process.exit(1);
    }

    try {
        console.log(`Processing Admin for phone: ${phoneNumber}...`);

        // 1. Get or Create User in Auth
        let userRecord;
        try {
            userRecord = await auth.getUserByPhoneNumber(phoneNumber);
            console.log(`Auth User found: ${userRecord.uid}`);
        } catch (error: any) {
            if (error.code === 'auth/user-not-found') {
                console.log("User not found in Auth, creating new user...");
                userRecord = await auth.createUser({
                    phoneNumber: phoneNumber,
                    displayName: 'Admin User',
                });
                console.log(`Auth User created: ${userRecord.uid}`);
            } else {
                throw error;
            }
        }

        const uid = userRecord.uid;

        // 2. Set Custom Claims (Optional but recommended for robust security rules)
        console.log("Setting custom claims...");
        await auth.setCustomUserClaims(uid, { role: 'admin' });

        // 3. Create/Update Firestore Document
        console.log("Updating Firestore user profile...");
        await db.collection("users").doc(uid).set({
            uid: uid,
            phoneNumber: phoneNumber,
            role: 'admin',
            active: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            // Only set createdAt if it doesn't exist (handled by merge=true effectively updating what we need)
        }, { merge: true });

        console.log(`\nSUCCESS: User ${phoneNumber} (${uid}) is now an Admin.`);
        process.exit(0);
    } catch (error) {
        console.error("FAILED to create admin:", error);
        process.exit(1);
    }
}

// Get phone number from arguments
// argv: [node, script, arg1, ...]
const args = process.argv.slice(2);
// Simple argument parsing, expects phone number as first arg
const phone = args[0];

createAdmin(phone);
