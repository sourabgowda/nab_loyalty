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
exports.addFuelTransaction = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
exports.addFuelTransaction = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Manager login required.");
    }
    // 1. Inputs
    const { userId, bunkId, amount, fuelType, isRedeem, requestId, pointsToRedeem } = request.data;
    const managerId = request.auth.uid;
    if (!userId || !bunkId || !amount || !fuelType || !requestId) {
        throw new https_1.HttpsError("invalid-argument", "Missing required fields.");
    }
    // 2. Validate Manager and Bunk
    const bunkSnap = await db.collection("bunks").doc(bunkId).get();
    if (!bunkSnap.exists) {
        throw new https_1.HttpsError("not-found", "Bunk not found.");
    }
    const bunkData = bunkSnap.data();
    const isAuthorized = (bunkData.managerIds && bunkData.managerIds.includes(managerId)) ||
        (bunkData.managerId === managerId);
    if (!isAuthorized) {
        throw new https_1.HttpsError("permission-denied", "Not authorized for this bunk.");
    }
    // 3. Idempotency Check
    const txRef = db.collection("transactions").doc(requestId);
    const existingTx = await txRef.get();
    if (existingTx.exists) {
        return { success: true, message: "Transaction already processed.", txId: existingTx.id };
    }
    try {
        await db.runTransaction(async (t) => {
            // 4. Read Config, User, & Stats
            const configSnap = await t.get(db.collection("globalConfig").doc("main"));
            if (!configSnap.exists) {
                throw new https_1.HttpsError("failed-precondition", "System config missing.");
            }
            const config = configSnap.data();
            const userRef = db.collection("users").doc(userId);
            const userSnap = await t.get(userRef);
            if (!userSnap.exists) {
                throw new https_1.HttpsError("not-found", "User not found.");
            }
            const userData = userSnap.data();
            // Pre-read Bunk Stats (Must be done before any writes)
            const today = new Date().toISOString().split('T')[0];
            const statsId = `${today}_${bunkId}`;
            const statsRef = db.collection("bunkDailyStats").doc(statsId);
            const statsSnap = await t.get(statsRef);
            // 5. Logic
            let pointsChange = 0;
            let finalAmount = amount;
            let pointsRedeemed = 0;
            if (isRedeem) {
                // Redemption Logic
                const pointsToUse = pointsToRedeem || 0;
                if (pointsToUse <= 0) {
                    throw new https_1.HttpsError("invalid-argument", "Points to redeem must be greater than 0.");
                }
                if (userData.points < config.minRedeemPoints) {
                    throw new https_1.HttpsError("failed-precondition", `Minimum ${config.minRedeemPoints} points required to redeem.`);
                }
                if (userData.points < pointsToUse) {
                    throw new https_1.HttpsError("resource-exhausted", "Insufficient points.");
                }
                const discount = pointsToUse * config.pointValue;
                if (discount > amount) {
                    throw new https_1.HttpsError("invalid-argument", "Cannot redeem more than the transaction amount.");
                }
                pointsChange = -pointsToUse;
                pointsRedeemed = pointsToUse;
                finalAmount = amount - discount;
            }
            else {
                // Credit Logic
                const pct = config.creditPercentage || 1;
                const valueBack = amount * (pct / 100);
                pointsChange = Math.floor(valueBack / (config.pointValue || 1));
            }
            // 6. Writes
            // Update User
            t.update(userRef, {
                points: admin.firestore.FieldValue.increment(pointsChange),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            // Create Transaction
            t.set(txRef, {
                txId: requestId,
                userId,
                bunkId,
                managerId,
                amount: finalAmount, // Amount Paid by User
                fuelAmount: amount, // Total Fuel Value
                paidAmount: finalAmount,
                fuelType,
                points: pointsChange,
                pointsRedeemed: pointsRedeemed,
                type: isRedeem ? 'REDEEM' : 'CREDIT',
                pointValue: config.pointValue ?? 1,
                creditPercentage: config.creditPercentage ?? 1,
                minRedeemPoints: config.minRedeemPoints ?? 500,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                requestId
            });
            // Update Bunk Daily Stats
            if (!statsSnap.exists) {
                t.set(statsRef, {
                    id: statsId,
                    bunkId,
                    date: today,
                    totalFuelAmount: amount,
                    totalPointsDistributed: pointsChange > 0 ? pointsChange : 0,
                    totalPointsRedeemed: pointsRedeemed,
                    transactionCount: 1
                });
            }
            else {
                t.update(statsRef, {
                    totalFuelAmount: admin.firestore.FieldValue.increment(amount),
                    totalPointsDistributed: admin.firestore.FieldValue.increment(pointsChange > 0 ? pointsChange : 0),
                    totalPointsRedeemed: admin.firestore.FieldValue.increment(pointsRedeemed),
                    transactionCount: admin.firestore.FieldValue.increment(1)
                });
            }
            // Audit Log: Removed per user request to keep tables separate.
            // Transaction data is already in 'transactions' collection.
        });
        return { success: true };
    }
    catch (error) {
        logger.error("Transaction failed", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Transaction failed to process.");
    }
});
//# sourceMappingURL=transaction.js.map