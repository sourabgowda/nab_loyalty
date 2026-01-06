
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { GlobalConfig, User, Bunk } from "../models/types";

const db = admin.firestore();

export const addFuelTransaction = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Manager login required.");
    }

    // 1. Inputs
    const { userId, bunkId, amount, fuelType, isRedeem, requestId, pointsToRedeem } = request.data;
    const managerId = request.auth.uid;

    if (!userId || !bunkId || !amount || !fuelType || !requestId) {
        throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    // 2. Validate Manager and Bunk
    const bunkSnap = await db.collection("bunks").doc(bunkId).get();
    if (!bunkSnap.exists) {
        throw new HttpsError("not-found", "Bunk not found.");
    }
    const bunkData = bunkSnap.data() as Bunk;

    const isAuthorized = (bunkData.managerIds && bunkData.managerIds.includes(managerId)) ||
        (bunkData.managerId === managerId);

    if (!isAuthorized) {
        throw new HttpsError("permission-denied", "Not authorized for this bunk.");
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
                throw new HttpsError("failed-precondition", "System config missing.");
            }
            const config = configSnap.data() as GlobalConfig;

            const userRef = db.collection("users").doc(userId);
            const userSnap = await t.get(userRef);
            if (!userSnap.exists) {
                throw new HttpsError("not-found", "User not found.");
            }
            const userData = userSnap.data() as User;

            // Pre-read Bunk Stats (Must be done before any writes)
            const now = new Date();
            // Convert to IST (UTC + 5:30) to ensure "Business Day" alignment for India
            const istDate = new Date(now.getTime() + (5.5 * 60 * 60 * 1000));
            const today = istDate.toISOString().split('T')[0];
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
                    throw new HttpsError("invalid-argument", "Points to redeem must be greater than 0.");
                }

                if (userData.points < config.minRedeemPoints) {
                    throw new HttpsError("failed-precondition", `Minimum ${config.minRedeemPoints} points required to redeem.`);
                }
            }

            // Check Global Max Fuel Limit
            const maxFuel = config.maxFuelAmount || 50000;
            if (amount > maxFuel) {
                throw new HttpsError("invalid-argument", `Amount exceeds the maximum limit of ₹${maxFuel}.`);
            }

            if (isRedeem) {
                // Redemption Logic
                const pointsToUse = pointsToRedeem || 0;

                if (pointsToUse <= 0) {
                    throw new HttpsError("invalid-argument", "Points to redeem must be greater than 0.");
                }

                if (userData.points < pointsToUse) {
                    throw new HttpsError("resource-exhausted", "Insufficient points.");
                }

                const discount = pointsToUse * config.pointValue;

                if (discount > amount) {
                    throw new HttpsError("invalid-argument", "Cannot redeem more than the transaction amount.");
                }

                pointsChange = -pointsToUse;
                pointsRedeemed = pointsToUse;
                finalAmount = amount - discount;

            } else {
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
                fuelAmount: amount,  // Total Fuel Value
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
                // Initialize new Daily Doc
                t.set(statsRef, {
                    id: statsId,
                    bunkId,
                    date: today,
                    totalFuelAmount: amount,
                    totalPaidAmount: finalAmount,
                    totalPointsDistributed: pointsChange > 0 ? pointsChange : 0,
                    totalPointsRedeemed: pointsRedeemed,
                    transactionCount: 1,
                    managers: {
                        [managerId]: {
                            fuelAmount: amount,
                            paidAmount: finalAmount,
                            pointsCredited: pointsChange > 0 ? pointsChange : 0,
                            pointsRedeemed: pointsRedeemed,
                            txCount: 1
                        }
                    }
                });
            } else {
                // Update Existing Daily Doc
                // Note: We cannot use array-union or simple increment for nested map keys cleanly without knowing they exist.
                // However, dot notation works for updates if the map key exists or we merge.
                // But Firestore 'update' with dot notation for nested keys is standard.
                // e.g. "managers.UID.fuelAmount": FieldValue.increment(...)

                const statsData = statsSnap.data() as any; // Cast to access dynamic keys safely if needed, or use dot notation
                // const managerStatsPath = `managers.${managerId}`;

                // Check if this manager already has stats for today to avoid undefined errors if blindly incrementing?
                // Actually, FieldValue.increment works even if field doesn't exist (treats as 0).
                // BUT, the parent `managers.UID` object must exist? No, deep nested updates create structure?
                // No, Firestore requires the map path to be valid.
                // Safe approach: Read current structure, or use set with merge?
                // Set with merge is difficult with increments.
                // Best approach: If manager entry missing, we can't increment deep fields.

                // Let's check existence in the read snapshot data.
                const managersMap = statsData.managers || {};
                const hasManagerEntry = !!managersMap[managerId];

                if (!hasManagerEntry) {
                    // Initialize this manager's entry
                    t.update(statsRef, {
                        totalFuelAmount: admin.firestore.FieldValue.increment(amount),
                        totalPaidAmount: admin.firestore.FieldValue.increment(finalAmount),
                        totalPointsDistributed: admin.firestore.FieldValue.increment(pointsChange > 0 ? pointsChange : 0),
                        totalPointsRedeemed: admin.firestore.FieldValue.increment(pointsRedeemed),
                        transactionCount: admin.firestore.FieldValue.increment(1),
                        [`managers.${managerId}`]: {
                            fuelAmount: amount,
                            paidAmount: finalAmount,
                            pointsCredited: pointsChange > 0 ? pointsChange : 0,
                            pointsRedeemed: pointsRedeemed,
                            txCount: 1
                        }
                    });
                } else {
                    // Increment existing entry
                    t.update(statsRef, {
                        totalFuelAmount: admin.firestore.FieldValue.increment(amount),
                        totalPaidAmount: admin.firestore.FieldValue.increment(finalAmount),
                        totalPointsDistributed: admin.firestore.FieldValue.increment(pointsChange > 0 ? pointsChange : 0),
                        totalPointsRedeemed: admin.firestore.FieldValue.increment(pointsRedeemed),
                        transactionCount: admin.firestore.FieldValue.increment(1),
                        [`managers.${managerId}.fuelAmount`]: admin.firestore.FieldValue.increment(amount),
                        [`managers.${managerId}.paidAmount`]: admin.firestore.FieldValue.increment(finalAmount),
                        [`managers.${managerId}.pointsCredited`]: admin.firestore.FieldValue.increment(pointsChange > 0 ? pointsChange : 0),
                        [`managers.${managerId}.pointsRedeemed`]: admin.firestore.FieldValue.increment(pointsRedeemed),
                        [`managers.${managerId}.txCount`]: admin.firestore.FieldValue.increment(1)
                    });
                }
            }

            // Audit Log: Removed per user request to keep tables separate.
            // Transaction data is already in 'transactions' collection.
        });

        return { success: true };
    } catch (error) {
        logger.error("Transaction failed", error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", "Transaction failed to process.");
    }
});
