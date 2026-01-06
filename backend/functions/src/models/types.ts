export type UserRole = 'customer' | 'manager' | 'admin';

export interface User {
    uid: string;
    phoneNumber: string;
    role: UserRole;
    points: number;
    name?: string;
    email?: string;
    pinHash?: string;
    pinSalt?: string;
    createdAt: FirebaseFirestore.Timestamp;
    updatedAt: FirebaseFirestore.Timestamp;
    isPinSet: boolean;
    metadata?: {
        failedAttempts?: number;
        lockoutUntil?: FirebaseFirestore.Timestamp;
    };
}

export interface Bunk {
    bunkId: string;
    name: string;
    location: string;
    managerId?: string; // Deprecated, use managerIds
    managerIds: string[]; // List of UIDs
    active: boolean;
    fuelTypes: string[]; // Bunk specific allowed types
    createdAt: FirebaseFirestore.Timestamp;
}

export type TransactionType = 'CREDIT' | 'REDEEM';

export interface Transaction {
    txId: string;
    userId: string;
    bunkId: string;
    managerId: string;
    amount: number; // Fuel amount in currency
    fuelType: string;
    points: number; // Earned or burned (negative if burned? or just type determines?)
    // Let's stick to positive points, type determines add/sub.
    type: TransactionType;
    timestamp: FirebaseFirestore.Timestamp;
    requestId: string; // Idempotency key
}

export interface BunkDailyStats {
    id: string; // composite key: YYYY-MM-DD_bunkId
    bunkId: string;
    date: string; // YYYY-MM-DD
    totalFuelAmount: number;
    totalPaidAmount: number;
    totalPointsDistributed: number;
    totalPointsRedeemed: number;
    transactionCount: number;
    managers: {
        [managerId: string]: {
            fuelAmount: number;
            paidAmount: number;
            pointsCredited: number;
            pointsRedeemed: number;
            txCount: number;
            // Hydrated fields (not stored)
            managerName?: string;
        }
    };
}

export interface GlobalConfig {
    pointValue: number; // e.g. 1 point = 1 INR
    creditPercentage: number; // e.g. 1% of fuel amount
    minRedeemPoints: number;
    maxFuelAmount: number;
    fuelTypes: string[]; // ['Petrol', 'Diesel']
}

export type AuditChangeType = 'CREATE' | 'UPDATE' | 'DELETE' | 'ROLE_CHANGE' | 'PIN_RESET' | 'DISABLE' | 'TRANSACTION';

export interface AuditLog {
    auditId: string;
    actorId: string;
    targetUserId?: string; // If applicable
    targetBunkId?: string; // If applicable
    changeType: AuditChangeType;
    details: any; // Flexible payload (oldValue, newValue)
    timestamp: FirebaseFirestore.Timestamp;
}

