//
//  PanLaw.swift
//  ScarlettKit
//
//  Level/pan ⇄ left/right gains. Linear pan law: centre = −6 dB per side,
//  hard left = full level on the left and −∞ on the right. Matches
//  Focusrite's software (centred inputs read −6 dB in each side of a mix).
//

import Foundation

public enum PanLaw {
    /// L/R gains in dB (−128 = −∞) → (level in dB, pan −1…+1).
    public static func levelPan(_ l: Double, _ r: Double) -> (Double, Double) {
        let a = l <= -128 ? 0 : pow(10, l / 20), b = r <= -128 ? 0 : pow(10, r / 20), s = a + b
        return s > 0 ? (20 * log10(s), (b - a) / s) : (-128, 0)
    }

    /// (level in dB, pan −1…+1) → L/R gains in dB, each clamped to +6 dB.
    public static func gains(level: Double, pan: Double) -> (Double, Double) {
        guard level > -128 else { return (-128, -128) }
        let s = pow(10, level / 20)
        func db(_ x: Double) -> Double { x <= 1e-6 ? -128 : min(6, 20 * log10(x)) }
        return (db(s * (1 - pan) / 2), db(s * (1 + pan) / 2))
    }
}
