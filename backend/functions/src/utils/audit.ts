import * as admin from "firebase-admin";
import * as AuditTypes from "../models/types";

// Get DB instance if not passed, but usually initialized in index.ts
// We'll rely on admin.app() being initialized.

export const logAudit = async (
    actorId: string,
    changeType: AuditTypes.AuditChangeType,
    details: any,
    targetUserId?: string,
    targetBunkId?: string
) => {
    const db = admin.firestore();
    await db.collection("auditLogs").add({
        actorId,
        changeType,
        details,
        targetUserId: targetUserId || null,
        targetBunkId: targetBunkId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
};
