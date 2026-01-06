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
exports.fetchAuditLogs = exports.fetchAnalytics = exports.fetchTransactions = exports.getUserProfile = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
exports.getUserProfile = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login required");
    }
    // Role based access?
    // User can read their own. Admin can read all. Manager can read ... customers?
    const { uid } = request.data; // fetch for specific user or all?
    const callerUid = request.auth.uid;
    // Get Caller Role
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data();
    let targetUid = uid || callerUid; // Default to caller's UID if not specified
    // Admin can fetch any user's profile
    if (caller.role === 'admin' && uid) {
        targetUid = uid;
    }
    else if (caller.role === 'customer' && uid && uid !== callerUid) {
        // Customer can only fetch their own profile
        throw new https_1.HttpsError("permission-denied", "Customers can only view their own profile.");
    }
    else if (caller.role === 'manager') {
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
        throw new https_1.HttpsError("not-found", "User not found.");
    }
    const userProfile = userSnap.data();
    // Remove sensitive data if not admin or self
    if (caller.role !== 'admin' && targetUid !== callerUid) {
        delete userProfile?.email; // Example of sensitive data
        // Add more fields to remove as needed
    }
    return { user: userProfile };
});
exports.fetchTransactions = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be logged in.");
    }
    const { uid, bunkId, fuelType, type, limit = 20, startDate, endDate, managerId } = request.data;
    const callerUid = request.auth.uid;
    // Get Caller Role
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data();
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
    }
    else if (caller.role === 'manager') {
        // Manager sees transactions for their bunk
        // 1. Find Bunk where managerIds contains callerUid
        const bunkSnap = await db.collection("bunks")
            .where("managerIds", "array-contains", callerUid)
            .limit(1)
            .get();
        if (bunkSnap.empty) {
            // Fallback to legacy check (optional, but good for safety)
            const legacySnap = await db.collection("bunks").where("managerId", "==", callerUid).limit(1).get();
            if (legacySnap.empty)
                return { transactions: [] };
            query = query.where("bunkId", "==", legacySnap.docs[0].id);
        }
        else {
            query = query.where("bunkId", "==", bunkSnap.docs[0].id);
        }
        // Manager filters
        if (fuelType && fuelType !== 'All')
            query = query.where("fuelType", "==", fuelType);
        if (type && type !== 'All')
            query = query.where("type", "==", type);
        // Filter by specific manager (e.g. "Only My Logs")
        if (managerId) {
            query = query.where("managerId", "==", managerId);
        }
    }
    else if (caller.role === 'admin') {
        // Admin filters
        if (uid)
            query = query.where("userId", "==", uid);
        if (bunkId)
            query = query.where("bunkId", "==", bunkId);
        if (fuelType && fuelType !== 'All')
            query = query.where("fuelType", "==", fuelType);
        if (type && type !== 'All')
            query = query.where("type", "==", type);
        if (managerId)
            query = query.where("managerId", "==", managerId);
    }
    if (!startDate) {
        // Only limit if NOT filtering by date range (or limit effectively applies to range too)
        query = query.limit(limit);
    }
    const snapshot = await query.get();
    const transactions = snapshot.docs.map(doc => doc.data());
    // Hydrate with User Details
    const userIds = new Set();
    transactions.forEach((tx) => {
        if (tx.userId)
            userIds.add(tx.userId);
    });
    if (userIds.size > 0) {
        const userRefs = Array.from(userIds).map(id => db.collection("users").doc(id));
        const userSnaps = await db.getAll(...userRefs); // Efficient batch read
        const userMap = new Map();
        userSnaps.forEach(snap => {
            if (snap.exists)
                userMap.set(snap.id, snap.data());
        });
        transactions.forEach((tx) => {
            if (tx.userId && userMap.has(tx.userId)) {
                const u = userMap.get(tx.userId);
                tx.userName = u.name || 'Unknown';
                tx.userPhone = u.phoneNumber || '';
            }
        });
    }
    return { transactions };
});
exports.fetchAnalytics = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login required");
    // Verify Admin (or Manager?)
    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const caller = callerSnap.data();
    if (caller.role !== 'admin') {
        throw new https_1.HttpsError("permission-denied", "Only admins can view global analytics.");
    }
    // Query Aggregated Stats
    // Ideally we filter by date range. For now, fetch last 30 entries (days/bunks mix).
    // Or filter by bunkId if provided.
    // Simple implementation: Fetch all stats for Dashboard (limit 50)
    // Ordered by date desc
    const query = db.collection("bunkDailyStats").orderBy("date", "desc").limit(50);
    const snapshot = await query.get();
    const stats = snapshot.docs.map(doc => doc.data());
    // ... existing code ...
    return stats; // Returns List<BunkDailyStats>
});
exports.fetchAuditLogs = (0, https_1.onCall)({ cors: true }, async (request) => {
    try {
        if (!request.auth)
            throw new https_1.HttpsError("unauthenticated", "Login required");
        const callerUid = request.auth.uid;
        // console.log("FetchAuditLogs called by", callerUid);
        const callerSnap = await db.collection("users").doc(callerUid).get();
        if (!callerSnap.exists) {
            throw new https_1.HttpsError("unauthenticated", "User profile not found.");
        }
        const caller = callerSnap.data();
        if (caller.role !== 'admin') {
            throw new https_1.HttpsError("permission-denied", "Only admins can view audit logs.");
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
        const userIdsToCheck = new Set();
        logs.forEach((log) => {
            if (log.actorId)
                userIdsToCheck.add(log.actorId);
            if (log.targetUserId)
                userIdsToCheck.add(log.targetUserId);
        });
        if (userIdsToCheck.size > 0) {
            const userPromises = Array.from(userIdsToCheck).map(uid => db.collection("users").doc(uid).get());
            const userSnaps = await Promise.all(userPromises);
            const userMap = new Map();
            userSnaps.forEach(snap => {
                if (snap.exists) {
                    userMap.set(snap.id, snap.data());
                }
            });
            logs.forEach((log) => {
                // Actor Hydration
                if (log.actorId && userMap.has(log.actorId)) {
                    const actor = userMap.get(log.actorId);
                    log.actorPhone = actor.phoneNumber || "No Phone";
                    log.actorName = actor.name || "Unknown";
                }
                else {
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
    }
    catch (error) {
        console.error("FetchAuditLogs Error", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Failed to fetch logs: " + error.message);
    }
});
//# sourceMappingURL=data.js.map