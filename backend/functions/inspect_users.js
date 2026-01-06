
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUsers() {
    const snapshot = await db.collection('users').limit(10).get();
    snapshot.forEach(doc => {
        console.log(`User: ${doc.id}, Phone: ${doc.data().phoneNumber}`);
    });
}

checkUsers();
