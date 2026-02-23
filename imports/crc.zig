//! # CRC Helper Aliases (`crc`)
//!
//! **What:** Convenience re-exports for CRC checksum functions — both the
//! hardware-accelerated ESP ROM versions and the Zig standard-library
//! software implementations.
//!
//! **What it does:**
//!   - `crc8(crc, buf, len)` — ESP ROM CRC-8.
//!   - `crc16(crc, buf, len)` — ESP ROM CRC-16.
//!   - `crc32(crc, buf, len)` — ESP ROM CRC-32 (hardware-accelerated on most
//!     ESP32 variants).
//!   - `zigCRC32` — Zig `std.hash.crc` module with all standard CRC
//!     algorithms for when you need a specific polynomial.
//!
//! **How:** Direct re-export — the ROM functions are linked from the bootloader
//! ROM symbol table; the Zig CRC is pure comptime/software.
//!
//! **When to use:** Protocol framing, NVS integrity, file checksum validation,
//! or anywhere a fast checksum is needed.
//!
//! **What it takes:**
//!   - `crc` (initial value / seed, usually `0` or `0xFFFFFFFF`).
//!   - `buf` (pointer to data bytes).
//!   - `len` (byte count).
//!
//! **Example:**
//! ```zig
//! const checksum = idf.crc.crc32(0xFFFFFFFF, data.ptr, data.len);
//! // Or use the pure-Zig CRC32 (IEEE):
//! const zig_crc = idf.crc.zigCRC32.Crc32.hash(data);
//! ```

const sys = @import("sys");

/// ESP ROM hardware-accelerated CRC-8 checksum.
///
/// Computes an 8-bit CRC over `buf[0..len]` using the initial seed `crc`.
pub const crc8 = sys.esp_rom_crc8;

/// ESP ROM hardware-accelerated CRC-16 checksum.
///
/// Computes a 16-bit CRC over `buf[0..len]` using the initial seed `crc`.
pub const crc16 = sys.esp_rom_crc16;

/// ESP ROM hardware-accelerated CRC-32 checksum.
///
/// Computes a 32-bit CRC over `buf[0..len]` using the initial seed `crc`.
/// On most ESP32 variants this leverages dedicated hardware.
pub const crc32 = sys.esp_rom_crc32;

/// Zig standard-library CRC module.
///
/// Provides pure-software CRC algorithms (`Crc32`, `Crc16Ccitt`, etc.)
/// for when you need a specific polynomial or a comptime-evaluable CRC.
pub const zigCRC32 = @import("std").hash.crc;
