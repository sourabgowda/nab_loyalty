import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { User } from "../models/types";
import { logAudit } from "../utils/audit";

const db = admin.firestore();

export const manageBunk = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const callerData = callerSnap.data() as User;

    if (callerData.role !== 'admin') {
        throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { action, bunkId, name, location, managerIds, managerId, active, fuelTypes } = request.data;
    const finalManagerIds = managerIds || (managerId ? [managerId] : []);

    if (!action) {
        throw new HttpsError("invalid-argument", "Action required (create, update, delete).");
    }

    try {
        // Uniqueness Check
        if (finalManagerIds.length > 0 && (action === 'create' || action === 'update')) {
            const duplicateCheck = await db.collection("bunks")
                .where("managerIds", "array-contains-any", finalManagerIds)
                .get();

            for (const doc of duplicateCheck.docs) {
                if (doc.id !== (bunkId || '')) {
                    throw new HttpsError("failed-precondition", `Manager is already assigned to bunk: ${doc.data().name}`);
                }
            }
        }

        if (action === 'create') {
            if (!name || !location) {
                throw new HttpsError("invalid-argument", "Bunk name and location are required.");
            }
            const newBunkRef = db.collection("bunks").doc();
            const id = bunkId || newBunkRef.id;
            const newBunk = {
                bunkId: id,
                name,
                location,
                managerIds: finalManagerIds,
                active: true,
                fuelTypes: fuelTypes || ['Petrol', 'Diesel'],
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            };
            await db.collection("bunks").doc(id).set(newBunk);

            await logAudit(callerUid, 'CREATE', { collection: 'bunks', id }, undefined, id);

            return { success: true, bunkId: id };

        } else if (action === 'update') {
            if (!bunkId) throw new HttpsError("invalid-argument", "Bunk ID required.");

            // 1. Pre-fetch existing data for diffing
            const bunkRef = db.collection("bunks").doc(bunkId);
            const bunkSnap = await bunkRef.get();
            if (!bunkSnap.exists) throw new HttpsError("not-found", "Bunk not found.");
            const oldData = bunkSnap.data() as any;

            const updates: any = {};
            // We construct 'changes' for the Audit Log: { field: { from: X, to: Y } }
            const changes: any = {};

            if (name !== undefined) {
                updates.name = name;
                if (oldData.name !== name) changes.name = { from: oldData.name, to: name };
            }
            if (location !== undefined) {
                updates.location = location;
                if (oldData.location !== location) changes.location = { from: oldData.location, to: location };
            }
            if (finalManagerIds.length > 0) {
                updates.managerIds = finalManagerIds;
                // Array compare (simplified)
                const oldM = JSON.stringify(oldData.managerIds?.sort() || []);
                const newM = JSON.stringify(finalManagerIds.sort());
                if (oldM !== newM) changes.managerIds = { from: oldData.managerIds, to: finalManagerIds };
            }
            if (active !== undefined) {
                updates.active = active;
                if (oldData.active !== active) changes.active = { from: oldData.active, to: active };
            }
            if (fuelTypes) {
                updates.fuelTypes = fuelTypes;
                const oldF = JSON.stringify(oldData.fuelTypes?.sort() || []);
                const newF = JSON.stringify(fuelTypes.sort());
                if (oldF !== newF) changes.fuelTypes = { from: oldData.fuelTypes, to: fuelTypes };
            }

            if (Object.keys(updates).length > 0) {
                await bunkRef.update(updates);
                // Only log if actual changes occurred (or if we trust frontend diff, but double check doesn't hurt)
                if (Object.keys(changes).length > 0) {
                    await logAudit(callerUid, 'UPDATE', { collection: 'bunks', id: bunkId, updates: changes }, undefined, bunkId);
                }
            }

            return { success: true };

        } else if (action === 'delete') {
            if (!bunkId) throw new HttpsError("invalid-argument", "Bunk ID required.");

            // Check safety
            const txSnap = await db.collection("transactions").where("bunkId", "==", bunkId).limit(1).get();
            if (!txSnap.empty) {
                throw new HttpsError("failed-precondition", "Cannot delete bunk with existing transactions.");
            }

            await db.collection("bunks").doc(bunkId).delete();
            await logAudit(callerUid, 'DELETE', { collection: 'bunks', id: bunkId }, undefined, bunkId);

            return { success: true };
        }

        return { success: false, message: "Invalid action" };
    } catch (error) {
        logger.error("Manage Bunk Error", error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", "Operation failed: " + (error as any).message); // Expose error for debug
    }
});

export const adminUpdateUser = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const callerData = callerSnap.data() as User;

    if (callerData.role !== 'admin') {
        throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { uid, role, points, name, email } = request.data;

    if (!uid) {
        throw new HttpsError("invalid-argument", "Target UID required.");
    }

    try {
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found");
        const oldData = userSnap.data() as any;

        const updates: any = {};
        const changes: any = {};

        if (role !== undefined) {
            updates.role = role;
            if (oldData.role !== role) changes.role = { from: oldData.role, to: role };
        }
        if (points !== undefined) {
            updates.points = points;
            if (oldData.points !== points) changes.points = { from: oldData.points, to: points };
        }
        if (name !== undefined) {
            updates.name = name;
            if (oldData.name !== name) changes.name = { from: oldData.name, to: name };
        }
        if (email !== undefined) {
            updates.email = email;
            if (oldData.email !== email) changes.email = { from: oldData.email, to: email };
        }

        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        // Audit Log
        const auditType = changes.role ? 'ROLE_CHANGE' : 'UPDATE';

        if (Object.keys(updates).length > 1) { // >1 because updatedAt is always there
            await userRef.set(updates, { merge: true });

            // EDGE CASE: If Role Changed FROM Manager TO something else, unassign from bunks
            if (changes.role && changes.role.from === 'manager' && changes.role.to !== 'manager') {
                const bunksManaged = await db.collection('bunks')
                    .where('managerIds', 'array-contains', uid)
                    .get();

                if (!bunksManaged.empty) {
                    const batch = db.batch();
                    bunksManaged.docs.forEach(doc => {
                        batch.update(doc.ref, {
                            managerIds: admin.firestore.FieldValue.arrayRemove(uid),
                            managerId: admin.firestore.FieldValue.delete() // Clear legacy field if present
                        });
                    });
                    await batch.commit();
                    logger.info(`Cleanup: Removed demoted manager ${uid} from ${bunksManaged.size} bunks.`);
                }
            }

            if (Object.keys(changes).length > 0) {
                await logAudit(callerUid, auditType, { uid, updates: changes }, uid);
            }
        }

        return { success: true };
    } catch (error) {
        logger.error("Admin Update User Error", error);
        throw new HttpsError("internal", "Operation failed");
    }
});

export const updateGlobalConfig = onCall(async (request) => {
    try {
        if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

        const callerUid = request.auth.uid;
        const callerSnap = await db.collection("users").doc(callerUid).get();

        if (!callerSnap.exists) {
            throw new HttpsError("unauthenticated", "User profile not found.");
        }

        const caller = callerSnap.data() as User;

        if (caller.role !== 'admin') {
            throw new HttpsError("permission-denied", "Admin access required.");
        }

        const { pointValue, creditPercentage, minRedeemPoints, maxFuelAmount, fuelTypes } = request.data;

        const configRef = db.collection("globalConfig").doc("main");
        const configSnap = await configRef.get();
        const oldData = configSnap.exists ? configSnap.data() as any : {};

        const updates: any = {};
        const changes: any = {};

        if (pointValue !== undefined) {
            updates.pointValue = pointValue;
            if (oldData.pointValue !== pointValue) changes.pointValue = { from: oldData.pointValue, to: pointValue };
        }
        if (creditPercentage !== undefined) {
            updates.creditPercentage = creditPercentage;
            if (oldData.creditPercentage !== creditPercentage) changes.creditPercentage = { from: oldData.creditPercentage, to: creditPercentage };
        }
        if (minRedeemPoints !== undefined) {
            updates.minRedeemPoints = minRedeemPoints;
            if (oldData.minRedeemPoints !== minRedeemPoints) changes.minRedeemPoints = { from: oldData.minRedeemPoints, to: minRedeemPoints };
        }
        if (maxFuelAmount !== undefined) {
            updates.maxFuelAmount = maxFuelAmount;
            if (oldData.maxFuelAmount !== maxFuelAmount) changes.maxFuelAmount = { from: oldData.maxFuelAmount, to: maxFuelAmount };
        }
        if (fuelTypes !== undefined) {
            updates.fuelTypes = fuelTypes;
            const oldF = JSON.stringify(oldData.fuelTypes?.sort() || []);
            const newF = JSON.stringify(fuelTypes.sort());
            if (oldF !== newF) changes.fuelTypes = { from: oldData.fuelTypes, to: fuelTypes };
        }

        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        await configRef.set(updates, { merge: true });

        if (Object.keys(changes).length > 0) {
            await logAudit(callerUid, 'UPDATE', { collection: 'globalConfig', updates: changes }, undefined, 'globalConfig');
        }

        return { success: true };
    } catch (error) {
        logger.error("Update Global Config Error", error);
        // ... existing code ...
        if (error instanceof HttpsError) throw error;
        throw new HttpsError("internal", "Operation failed: " + (error as any).message);
    }
});


export const deleteUser = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const callerData = callerSnap.data() as User;

    if (callerData.role !== 'admin') {
        throw new HttpsError("permission-denied", "Admin access required.");
    }

    const { uid } = request.data;
    if (!uid) {
        throw new HttpsError("invalid-argument", "Target UID required.");
    }

    try {
        // 1. Delete Firestore Profile
        await db.collection("users").doc(uid).delete();

        // 2. Disable Auth User (Best effort, requires Admin SDK Auth)
        try {
            await admin.auth().updateUser(uid, { disabled: true });
        } catch (authError) {
            logger.warn(`Failed to disable auth for user ${uid}`, authError);
            // Continue, as firestore delete is done.
        }

        // 3. Log Audit
        await logAudit(callerUid, 'DELETE', { collection: 'users', uid }, uid);

        return { success: true };
    } catch (error) {
        logger.error("Delete User Error", error);
        throw new HttpsError("internal", "Failed to delete user.");
    }
});

export const findUserByPhone = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const callerData = callerSnap.data() as User;

    if (callerData.role !== 'manager' && callerData.role !== 'admin') {
        throw new HttpsError("permission-denied", "Manager access required.");
    }

    const { phoneNumber } = request.data;
    if (!phoneNumber) throw new HttpsError("invalid-argument", "Phone number required.");

    // Normalize: Handle both raw 10 digit and +91 formats
    const rawNumber = phoneNumber.replace('+91', '').trim();
    const e164Number = `+91${rawNumber}`;

    try {
        // Parallel query for both formats
        const [e164Snap, rawSnap] = await Promise.all([
            db.collection("users").where("phoneNumber", "==", e164Number).limit(1).get(),
            db.collection("users").where("phoneNumber", "==", rawNumber).limit(1).get()
        ]);

        let userDoc: any = null;
        if (!e164Snap.empty) {
            userDoc = e164Snap.docs[0];
        } else if (!rawSnap.empty) {
            userDoc = rawSnap.docs[0];
        }

        if (!userDoc) {
            return { found: false };
        }

        const userData = userDoc.data();
        return {
            found: true,
            uid: userDoc.id,
            name: userData.name,
            points: userData.points || 0,
            phoneNumber: userData.phoneNumber
        };
    } catch (error) {
        logger.error("Find User Error", error);
        throw new HttpsError("internal", "Search failed.");
    }
});

export const registerCustomer = onCall(async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

    const callerUid = request.auth.uid;
    const callerSnap = await db.collection("users").doc(callerUid).get();
    const callerData = callerSnap.data() as User;

    if (callerData.role !== 'manager' && callerData.role !== 'admin') {
        throw new HttpsError("permission-denied", "Manager access required.");
    }

    const { phoneNumber, name } = request.data;
    if (!phoneNumber || !name) throw new HttpsError("invalid-argument", "Phone and Name required.");

    try {
        let uid = '';

        // 1. Check or Create Auth User
        try {
            const userRecord = await admin.auth().createUser({
                phoneNumber: phoneNumber,
                displayName: name,
                disabled: false
            });
            uid = userRecord.uid;
        } catch (authError: any) {
            if (authError.code === 'auth/phone-number-already-exists') {
                const userRecord = await admin.auth().getUserByPhoneNumber(phoneNumber);
                uid = userRecord.uid;
            } else {
                throw authError;
            }
        }

        // 2. Check Firestore
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();

        if (userSnap.exists) {
            // Already exists in Firestore? Return it.
            const userData = userSnap.data() as User;
            return {
                success: true,
                message: "User already exists.",
                uid,
                name: userData.name,
                points: userData.points || 0,
                phoneNumber: userData.phoneNumber
            };
        }

        // 3. Create Firestore Profile
        const newUser: User = {
            uid,
            phoneNumber,
            name,
            role: 'customer', // Always customer when registered by manager
            createdAt: admin.firestore.FieldValue.serverTimestamp() as any,
            updatedAt: admin.firestore.FieldValue.serverTimestamp() as any,
            points: 0,
            isPinSet: false
        };

        await userRef.set(newUser);
        await logAudit(callerUid, 'CREATE', { collection: 'users', uid, via: 'manager_register' }, uid);

        return {
            success: true,
            message: "Customer registered.",
            uid,
            name,
            points: 0,
            phoneNumber
        };

    } catch (error) {
        logger.error("Register Customer Error", error);
        throw new HttpsError("internal", "Registration failed: " + (error as any).message);
    }
});
