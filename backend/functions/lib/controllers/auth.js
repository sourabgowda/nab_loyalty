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
exports.updateProfile = exports.resetPin = exports.verifyPin = exports.setPin = exports.onUserCreate = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const security_1 = require("../utils/security");
const audit_1 = require("../utils/audit");
const db = admin.firestore();
// Helper to validate and clean Indian phone number
// Returns 10 digit number if valid Indian number (starts with +91 and has 10 digits)
// Returns null if invalid
const getValidIndianNumber = (phone) => {
    if (!phone)
        return null;
    // Remove all spaces and dashes
    const clean = phone.replace(/[\s-]/g, '');
    if (clean.startsWith('+91') && clean.length === 13) {
        return clean.substring(3); // Return last 10 digits
    }
    return null;
};
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    const { uid, phoneNumber, email, displayName } = user;
    // VALIDATION: Indian Phone Number Only
    const validPhone = getValidIndianNumber(phoneNumber);
    // If invalid phone, we might want to delete the user or disable them? 
    // For now, we will log error and NOT create the user profile, effectively blocking them from the app logic.
    // Ideally we should disable the auth account too.
    // If invalid phone or missing phone, we disable the user and do NOT create a profile.
    if (!phoneNumber || !validPhone) {
        functions.logger.warn(`Blocking registration for invalid/missing phone: ${phoneNumber}`);
        try {
            await admin.auth().updateUser(uid, { disabled: true });
            await (0, audit_1.logAudit)(uid, 'DISABLE', { reason: 'Invalid Phone Format', phoneNumber }, uid);
        }
        catch (e) {
            functions.logger.error("Failed to disable invalid user", e);
        }
        return;
    }
    const newUser = {
        uid,
        phoneNumber: validPhone || null, // Store clean 10-digit number
        email: email || null,
        name: displayName || null,
        role: 'customer', // Default role
        points: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isPinSet: false
    };
    try {
        await db.collection("users").doc(uid).set(newUser);
        functions.logger.info(`User document created: ${uid}`);
    }
    catch (error) {
        functions.logger.error(`CRITICAL: Error creating user doc for ${uid}`, error);
        return; // Don't log audit if user doc failed
    }
    try {
        await (0, audit_1.logAudit)(uid, 'CREATE', { method: 'auth_trigger', phoneNumber: validPhone }, uid);
        functions.logger.info(`Audit log created for user registration: ${uid}`);
    }
    catch (auditError) {
        functions.logger.error(`CRITICAL: Failed to create audit log for user ${uid}`, auditError);
        // We do NOT re-throw here because we don't want to crash the function if just logging fails,
        // but it IS critical.
    }
});
// Helper to validate 4-digit PIN
const isValidPin = (pin) => /^\d{4}$/.test(pin);
const doSetPin = async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "User must be logged in.");
    }
    const { pin } = request.data;
    const uid = request.auth.uid;
    if (!isValidPin(pin)) {
        throw new https_1.HttpsError("invalid-argument", "PIN must be exactly 4 digits.");
    }
    try {
        const salt = (0, security_1.generateSalt)();
        const pinHash = (0, security_1.hashPin)(pin, salt);
        const userRef = db.collection("users").doc(uid);
        const userSnap = await userRef.get();
        const updates = {
            pinHash,
            pinSalt: salt,
            isPinSet: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        // Assign default 'customer' role if not already set
        if (!userSnap.exists || !userSnap.data()?.role) {
            updates.role = 'customer';
        }
        // Backfill Phone Number if missing (Self-Healing)
        if (!userSnap.exists || !userSnap.data()?.phoneNumber) {
            try {
                const authUser = await admin.auth().getUser(uid);
                if (authUser.phoneNumber) {
                    const validPhone = getValidIndianNumber(authUser.phoneNumber);
                    if (validPhone) {
                        updates.phoneNumber = validPhone;
                    }
                }
            }
            catch (e) {
                functions.logger.warn(`Failed to backfill phone for ${uid}`, e);
            }
        }
        await userRef.set(updates, { merge: true });
        // Log PIN set/reset
        // Identifying if it's set or reset might require checking previous state, 
        // but for now let's log as PIN_RESET which covers both securely.
        await (0, audit_1.logAudit)(uid, 'PIN_RESET', {}, uid);
        return { success: true };
    }
    catch (error) {
        functions.logger.error("Error setting PIN", error);
        throw new https_1.HttpsError("internal", "Failed to set PIN.");
    }
};
exports.setPin = (0, https_1.onCall)(doSetPin);
exports.verifyPin = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "User must be logged in.");
    }
    const { pin } = request.data;
    const uid = request.auth.uid;
    if (!isValidPin(pin)) {
        throw new https_1.HttpsError("invalid-argument", "PIN must be 4 digits.");
    }
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("not-found", "User not found.");
    }
    const userData = userDoc.data();
    // 1. Check Lockout
    if (userData.metadata && userData.metadata.lockoutUntil) {
        const lockoutTime = userData.metadata.lockoutUntil.toDate();
        if (lockoutTime > new Date()) {
            throw new https_1.HttpsError("resource-exhausted", "Too many failed attempts. Try again later.");
        }
    }
    // 2. Verify PIN
    if (!userData.pinHash || !userData.pinSalt) {
        throw new https_1.HttpsError("failed-precondition", "PIN not set.");
    }
    const isValid = (0, security_1.verifyPin)(pin, userData.pinHash, userData.pinSalt);
    if (isValid) {
        // Reset failed attempts on success
        await userRef.update({
            "metadata.failedAttempts": 0,
            "metadata.lockoutUntil": admin.firestore.FieldValue.delete()
        });
        return { success: true };
    }
    else {
        // Handle Failure
        const failedAttempts = (userData.metadata?.failedAttempts || 0) + 1;
        let updates = { "metadata.failedAttempts": failedAttempts };
        if (failedAttempts >= 5) {
            const lockoutTime = new Date();
            lockoutTime.setMinutes(lockoutTime.getMinutes() + 15);
            updates["metadata.lockoutUntil"] = admin.firestore.Timestamp.fromDate(lockoutTime);
        }
        await userRef.update(updates);
        throw new https_1.HttpsError("permission-denied", "Invalid PIN.");
    }
});
exports.resetPin = (0, https_1.onCall)(doSetPin);
exports.updateProfile = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Login required.");
    }
    const uid = request.auth.uid;
    const { name, email } = request.data;
    const updates = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    if (name)
        updates.name = name;
    if (email)
        updates.email = email;
    try {
        await db.collection("users").doc(uid).set(updates, { merge: true });
        await (0, audit_1.logAudit)(uid, 'UPDATE', { updates }, uid);
        return { success: true };
    }
    catch (error) {
        throw new https_1.HttpsError("internal", "Update failed.");
    }
});
//# sourceMappingURL=auth.js.map