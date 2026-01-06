"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTransactionCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const db = admin.firestore();
exports.onTransactionCreated = (0, firestore_1.onDocumentCreated)("transactions/{txId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        return;
    }
    const tx = snapshot.data();
    if (!tx || !tx.timestamp)
        return;
    const txDate = tx.timestamp.toDate();
    const dateStr = txDate.toISOString().split('T')[0]; // YYYY-MM-DD
    const bunkId = tx.bunkId;
    // Composite Key for Daily Stats
    const statsId = `${dateStr}_${bunkId}`;
    const statsRef = db.collection("bunkDailyStats").doc(statsId);
    await db.runTransaction(async (t) => {
        const doc = await t.get(statsRef);
        let totalFuel = 0;
        let totalPointsDist = 0;
        let totalPointsRedeemed = 0;
        let count = 0;
        if (doc.exists) {
            const data = doc.data();
            totalFuel = data.totalFuelAmount || 0;
            totalPointsDist = data.totalPointsDistributed || 0;
            totalPointsRedeemed = data.totalPointsRedeemed || 0;
            count = data.transactionCount || 0;
        }
        // Update values
        count += 1;
        // Assuming transaction amount is always positive fuel cost
        if (tx.amount) {
            totalFuel += tx.amount;
        }
        // Points logic
        // If type is CREDIT, points are added (distributed).
        // If type is REDEEM, points are used (redeemed).
        if (tx.type === 'CREDIT') {
            totalPointsDist += (tx.points || 0);
        }
        else if (tx.type === 'REDEEM') {
            totalPointsRedeemed += (tx.points || 0);
        }
        t.set(statsRef, {
            id: statsId,
            bunkId: bunkId,
            date: dateStr,
            totalFuelAmount: totalFuel,
            totalPointsDistributed: totalPointsDist,
            totalPointsRedeemed: totalPointsRedeemed,
            transactionCount: count,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    });
});
//# sourceMappingURL=analytics.js.map