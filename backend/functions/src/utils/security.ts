import * as crypto from 'crypto';

export const generateSalt = (): string => {
    return crypto.randomBytes(16).toString('hex');
};

export const hashPin = (pin: string, salt: string): string => {
    const hash = crypto.createHmac('sha256', salt);
    hash.update(pin);
    return hash.digest('hex');
};

export const verifyPin = (pin: string, hash: string, salt: string): boolean => {
    const calculatedHash = hashPin(pin, salt);
    return calculatedHash === hash;
};
