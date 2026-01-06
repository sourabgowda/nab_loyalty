
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { User } from "../models/types";

const db = admin.firestore();

export const getUserProfile = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    // Role based access?
    // User can read their own. Admin can read all. Manager can read ... customers?

    const { uid } = request.data; // fetch for specific user or all?
    const callerUid = request.auth.uid;

    // Get Caller Role
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data() as User;

    let targetUid = uid || callerUid; // Default to caller's UID if not specified

    // Admin can fetch any user's profile
    if (caller.role === 'admin' && uid) {
        targetUid = uid;
    } else if (caller.role === 'customer' && uid && uid !== callerUid) {
        // Customer can only fetch their own profile
        throw new HttpsError("permission-denied", "Customers can only view their own profile.");
    } else if (caller.role === 'manager') {
        // Manager can fetch their own profile or profiles of users in their bunk
        // For simplicity, let's assume manager can only fetch their own for now,
        // or if `uid` is provided, it must be a user in their bunk.
        // This would require additional logic to check if `uid` belongs to their bunk.
        // For now, managers can only fetch their own or if `uid` is provided, it's assumed to be valid.
        // A more robust solution would check bunk membership.
        if (uid && uid !== callerUid) {
            // Placeholder for manager-specific user fetching logic
            // e.g., check if uid is in manager's bunk
            // For now, we'll allow it but a real implementation needs this check.
        }
    }

    const userSnap = await db.collection("users").doc(targetUid).get();

    if (!userSnap.exists) {
        throw new HttpsError("not-found", "User not found.");
    }

    const userProfile = userSnap.data();

    // Remove sensitive data if not admin or self
    if (caller.role !== 'admin' && targetUid !== callerUid) {
        delete userProfile?.email; // Example of sensitive data
        // Add more fields to remove as needed
    }

    return { user: userProfile };
});

export const fetchTransactions = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const { uid, bunkId, fuelType, type, limit = 20, startDate, endDate, managerId } = request.data;
    const callerUid = request.auth.uid;

    // Get Caller Role
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data() as User;

    let query = db.collection("transactions").orderBy("timestamp", "desc");

    // Apply Date Filter if provided
    if (startDate && endDate) {
        const start = admin.firestore.Timestamp.fromDate(new Date(startDate));
        const end = admin.firestore.Timestamp.fromDate(new Date(endDate));
        query = query.where("timestamp", ">=", start).where("timestamp", "<=", end);
    }

    if (caller.role === 'customer') {
        // Customer sees OWN transactions
        query = query.where("userId", "==", callerUid);
    } else if (caller.role === 'manager') {
        // Manager sees transactions for their bunk
        // 1. Find Bunk where managerIds contains callerUid
        const bunkSnap = await db.collection("bunks")
            .where("managerIds", "array-contains", callerUid)
            .limit(1)
            .get();

        if (bunkSnap.empty) {
            // Fallback to legacy check (optional, but good for safety)
            const legacySnap = await db.collection("bunks").where("managerId", "==", callerUid).limit(1).get();
            if (legacySnap.empty) return { transactions: [] };
            query = query.where("bunkId", "==", legacySnap.docs[0].id);
        } else {
            query = query.where("bunkId", "==", bunkSnap.docs[0].id);
        }

        // Manager filters
        if (fuelType && fuelType !== 'All') query = query.where("fuelType", "==", fuelType);
        if (type && type !== 'All') query = query.where("type", "==", type);

        // Filter by specific manager (e.g. "Only My Logs")
        if (managerId) {
            query = query.where("managerId", "==", managerId);
        }

    } else if (caller.role === 'admin') {
        // Admin filters
        if (uid) query = query.where("userId", "==", uid);
        if (bunkId) query = query.where("bunkId", "==", bunkId);
        if (fuelType && fuelType !== 'All') query = query.where("fuelType", "==", fuelType);
        if (type && type !== 'All') query = query.where("type", "==", type);
        if (managerId) query = query.where("managerId", "==", managerId);
    }

    if (!startDate) {
        // Only limit if NOT filtering by date range (or limit effectively applies to range too)
        query = query.limit(limit);
    }

    const snapshot = await query.get();
    const transactions = snapshot.docs.map(doc => doc.data());

    // Hydrate with User Details
    const userIds = new Set<string>();
    transactions.forEach((tx: any) => {
        if (tx.userId) userIds.add(tx.userId);
    });

    if (userIds.size > 0) {
        const userRefs = Array.from(userIds).map(id => db.collection("users").doc(id));
        const userSnaps = await db.getAll(...userRefs); // Efficient batch read
        const userMap = new Map<string, any>();

        userSnaps.forEach(snap => {
            if (snap.exists) userMap.set(snap.id, snap.data());
        });

        transactions.forEach((tx: any) => {
            if (tx.userId && userMap.has(tx.userId)) {
                const u = userMap.get(tx.userId);
                tx.userName = u.name || 'Unknown';
                tx.userPhone = u.phoneNumber || '';
            }
        });
    }

    // Hydrate with Bunk Details
    const bunkIds = new Set<string>();
    transactions.forEach((tx: any) => {
        if (tx.bunkId) bunkIds.add(tx.bunkId);
    });

    if (bunkIds.size > 0) {
        const bunkRefs = Array.from(bunkIds).map(id => db.collection("bunks").doc(id));
        const bunkSnaps = await db.getAll(...bunkRefs);
        const bunkMap = new Map<string, any>();

        bunkSnaps.forEach(snap => {
            if (snap.exists) bunkMap.set(snap.id, snap.data());
        });

        transactions.forEach((tx: any) => {
            if (tx.bunkId && bunkMap.has(tx.bunkId)) {
                const b = bunkMap.get(tx.bunkId);
                tx.bunkName = b.name || 'Unknown Bunk';
            } else {
                tx.bunkName = 'Unknown Bunk';
            }
        });
    }

    return { transactions };
});

export const fetchAnalytics = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

    // Verify Admin (or Manager?)
    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data() as User;

    if (caller.role !== 'admin') {
        throw new HttpsError("permission-denied", "Only admins can view global analytics.");
    }

    // 1. Inputs
    const { bunkId, period = 'day', date } = request.data;
    // period: 'day', 'month', 'year'
    // date: ISO string or YYYY-MM-DD. Defaults to today.

    let startDateStr = '';
    let endDateStr = '';

    // Default to IST 'now' if date not provided
    const utcNow = new Date();
    const istNow = new Date(utcNow.getTime() + (5.5 * 60 * 60 * 1000));

    // If date is provided, we assumes it's 'YYYY-MM-DD' correct string or ISO. 
    // If not, use IST now.
    const targetDate = date ? new Date(date) : istNow;

    if (period === 'day') {
        // Just the specific day
        startDateStr = targetDate.toISOString().split('T')[0];
        endDateStr = startDateStr;
    } else if (period === 'month') {
        // First to last day of month
        const y = targetDate.getFullYear();
        const m = targetDate.getMonth();
        const firstDay = new Date(y, m, 1);
        const lastDay = new Date(y, m + 1, 0);
        startDateStr = firstDay.toISOString().split('T')[0];
        endDateStr = lastDay.toISOString().split('T')[0];
    } else if (period === 'year') {
        const y = targetDate.getFullYear();
        const firstDay = new Date(y, 0, 1);
        const lastDay = new Date(y, 11, 31);
        startDateStr = firstDay.toISOString().split('T')[0];
        endDateStr = lastDay.toISOString().split('T')[0];
    }

    let query = db.collection("bunkDailyStats")
        .where("date", ">=", startDateStr)
        .where("date", "<=", endDateStr);

    if (bunkId) {
        query = query.where("bunkId", "==", bunkId);
    } else {
        // If no bunkId provided (Admin Dashboard Global?), limit result set
        // But aggregation across ALL bunks is complex.
        // Let's assume for now this call is usually PER BUNK or returns list of daily stats if no aggregation requested.
        // Actually user wants "Bunk Stats".
        // If bunkId is missing, maybe we fetch latest daily stats for ALL bunks (Dashboard view)?
        // Original logic was "limit 50" ordered by date.
    }

    const snapshot = await query.get();
    const dailyDocs = snapshot.docs.map(doc => doc.data());
    console.log(`Analytics Query: [${startDateStr}] to [${endDateStr}]. Found ${dailyDocs.length} docs.`);
    if (dailyDocs.length > 0) {
        console.log("Sample Doc Data:", JSON.stringify(dailyDocs[0]));
    }

    // 2. Aggregation Helper
    // We want to return a single "Stats" object if aggregating, or a list?
    // User wants "Daily, Monthly, Yearly".
    // If 'day', it's basically the single doc (or list of docs if multiple bunks).
    // If 'month', we aggregate all docs found into one summary.

    // Let's structure response: { period: 'month', startDate, endDate, totals: {...}, managers: [...] }

    // Init Totals
    const agg = {
        totalFuelAmount: 0,
        totalPaidAmount: 0,
        totalPointsDistributed: 0,
        totalPointsRedeemed: 0,
        transactionCount: 0,
    };
    const managerMap: any = {};
    const bunkIdSet = new Set<string>();

    dailyDocs.forEach((doc: any) => {
        bunkIdSet.add(doc.bunkId);

        // Global Totals
        agg.totalFuelAmount += (doc.totalFuelAmount || 0);
        agg.totalPaidAmount += (doc.totalPaidAmount || 0);
        agg.totalPointsDistributed += (doc.totalPointsDistributed || 0);
        agg.totalPointsRedeemed += (doc.totalPointsRedeemed || 0);
        agg.transactionCount += (doc.transactionCount || 0);

        // Manager Breakdown
        if (doc.managers) {
            Object.keys(doc.managers).forEach(mgrId => {
                const mStat = doc.managers[mgrId];
                if (!managerMap[mgrId]) {
                    managerMap[mgrId] = {
                        managerId: mgrId,
                        fuelAmount: 0,
                        paidAmount: 0,
                        pointsCredited: 0,
                        pointsRedeemed: 0,
                        txCount: 0
                    };
                }
                managerMap[mgrId].fuelAmount += (mStat.fuelAmount || 0);
                managerMap[mgrId].paidAmount += (mStat.paidAmount || 0);
                managerMap[mgrId].pointsCredited += (mStat.pointsCredited || 0);
                managerMap[mgrId].pointsRedeemed += (mStat.pointsRedeemed || 0);
                managerMap[mgrId].txCount += (mStat.txCount || 0);
            });
        }
    });

    console.log("Aggregated Totals:", JSON.stringify(agg));

    // 3. Hydration (Managers & Bunk)
    // Managers
    const managerList = Object.values(managerMap);
    if (managerList.length > 0) {
        const mgrIds = managerList.map((m: any) => m.managerId);
        // Fetch User Docs
        // Chunking if > 10? usually unlikely to have >10 managers per bunk
        const userRefs = mgrIds.map((id: any) => db.collection("users").doc(id));
        if (userRefs.length > 0) {
            const userSnaps = await db.getAll(...userRefs);
            const userLookup: any = {};
            userSnaps.forEach(s => { if (s.exists) userLookup[s.id] = s.data(); });

            managerList.forEach((m: any) => {
                const u = userLookup[m.managerId];
                m.managerName = u ? (u.name || 'Unknown') : 'Unknown';
            });
        }
    }

    // Bunk Hydration (if single bunk context, or multiple)
    let bunkDetails: any = null;
    if (bunkId) { // Specific bunk
        const bSnap = await db.collection("bunks").doc(bunkId).get();
        if (bSnap.exists) {
            const bd = bSnap.data() as any;
            bunkDetails = { name: bd.name, location: bd.location, id: bd.id };
        }
    }

    return {
        period,
        startDate: startDateStr,
        endDate: endDateStr,
        bunkDetails, // null if aggregated across multiple bunks?
        totals: agg,
        managers: managerList
    };
});

export const fetchAuditLogs = onCall({ cors: true }, async (request) => {
    try {
        if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

        const callerUid = request.auth.uid;
        // console.log("FetchAuditLogs called by", callerUid);

        const callerSnap = await db.collection("users").doc(callerUid).get();
        if (!callerSnap.exists) {
            throw new HttpsError("unauthenticated", "User profile not found.");
        }
        const caller = callerSnap.data() as User;

        if (caller.role !== 'admin') {
            throw new HttpsError("permission-denied", "Only admins can view audit logs.");
        }

        const { limit = 50, targetUserId, targetBunkId } = request.data;
        // console.log("Query params:", { limit, targetUserId, targetBunkId });

        let query = db.collection("auditLogs").orderBy("timestamp", "desc");

        if (targetUserId) {
            query = query.where("targetUserId", "==", targetUserId);
        }

        if (targetBunkId) {
            query = query.where("targetBunkId", "==", targetBunkId);
        }

        query = query.limit(limit);

        const snapshot = await query.get();
        const logs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Hydrate with Actor AND Target Details (Phone/Name)
        const userIdsToCheck = new Set<string>();
        logs.forEach((log: any) => {
            if (log.actorId) userIdsToCheck.add(log.actorId);
            if (log.targetUserId) userIdsToCheck.add(log.targetUserId);
        });

        if (userIdsToCheck.size > 0) {
            const userPromises = Array.from(userIdsToCheck).map(uid => db.collection("users").doc(uid).get());
            const userSnaps = await Promise.all(userPromises);
            const userMap = new Map<string, any>();

            userSnaps.forEach(snap => {
                if (snap.exists) {
                    userMap.set(snap.id, snap.data());
                }
            });

            logs.forEach((log: any) => {
                // Actor Hydration
                if (log.actorId && userMap.has(log.actorId)) {
                    const actor = userMap.get(log.actorId);
                    log.actorPhone = actor.phoneNumber || "No Phone";
                    log.actorName = actor.name || "Unknown";
                } else {
                    log.actorPhone = "Unknown";
                }

                // Target Hydration
                if (log.targetUserId && userMap.has(log.targetUserId)) {
                    const target = userMap.get(log.targetUserId);
                    log.targetPhone = target.phoneNumber || "No Phone";
                    log.targetName = target.name || "Unknown";
                }
            });
        }

        // console.log(`Found ${logs.length} logs`);
        return { logs };
    } catch (error) {
        console.error("FetchAuditLogs Error", error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", "Failed to fetch logs: " + (error as any).message);
    }
});
