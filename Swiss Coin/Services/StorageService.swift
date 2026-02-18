//
//  StorageService.swift
//  Swiss Coin
//
//  Handles photo uploads/downloads to Supabase Storage.
//  Compresses images before upload (max 800x800, JPEG 0.7 quality).
//

import Foundation
import Supabase
import UIKit

@MainActor
final class StorageService {
    static let shared = StorageService()
    private let client = SupabaseConfig.client

    private enum Bucket: String {
        case profilePhotos = "profile-photos"
        case groupPhotos = "group-photos"
        case receiptImages = "receipt-images"
    }

    // MARK: - Upload

    /// Upload a profile photo for the current user
    /// - Parameter imageData: Raw image data
    /// - Returns: Public URL string for the uploaded photo
    func uploadProfilePhoto(_ imageData: Data) async throws -> String {
        guard let userId = try? await client.auth.session.user.id else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(imageData)
        let path = "\(userId.uuidString)/avatar.jpg"

        try await client.storage
            .from(Bucket.profilePhotos.rawValue)
            .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))

        return try client.storage
            .from(Bucket.profilePhotos.rawValue)
            .getPublicURL(path: path)
            .absoluteString
    }

    /// Upload a group photo
    /// - Parameters:
    ///   - groupId: The group's UUID
    ///   - imageData: Raw image data
    /// - Returns: Public URL string
    func uploadGroupPhoto(groupId: UUID, _ imageData: Data) async throws -> String {
        guard let userId = try? await client.auth.session.user.id else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(imageData)
        let path = "\(userId.uuidString)/\(groupId.uuidString).jpg"

        try await client.storage
            .from(Bucket.groupPhotos.rawValue)
            .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))

        return try client.storage
            .from(Bucket.groupPhotos.rawValue)
            .getPublicURL(path: path)
            .absoluteString
    }

    /// Upload a receipt image (private)
    /// - Parameters:
    ///   - transactionId: The transaction's UUID
    ///   - imageData: Raw image data
    /// - Returns: Storage path (not public URL — use signed URL for access)
    func uploadReceiptImage(transactionId: UUID, _ imageData: Data) async throws -> String {
        guard let userId = try? await client.auth.session.user.id else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(imageData)
        let path = "\(userId.uuidString)/\(transactionId.uuidString).jpg"

        try await client.storage
            .from(Bucket.receiptImages.rawValue)
            .upload(path, data: compressed, options: .init(contentType: "image/jpeg", upsert: true))

        return path
    }

    // MARK: - Download

    /// Get a signed URL for a private receipt image
    func signedReceiptURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        try await client.storage
            .from(Bucket.receiptImages.rawValue)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }

    // MARK: - Delete

    func deleteProfilePhoto() async throws {
        guard let userId = try? await client.auth.session.user.id else { return }
        let path = "\(userId.uuidString)/avatar.jpg"
        try await client.storage.from(Bucket.profilePhotos.rawValue).remove(paths: [path])
    }

    func deleteGroupPhoto(groupId: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id else { return }
        let path = "\(userId.uuidString)/\(groupId.uuidString).jpg"
        try await client.storage.from(Bucket.groupPhotos.rawValue).remove(paths: [path])
    }

    // MARK: - Image Compression

    /// Compress image to max 800x800 at JPEG 0.7 quality
    private func compressImage(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            return resized.jpegData(compressionQuality: 0.7) ?? data
        }

        return image.jpegData(compressionQuality: 0.7) ?? data
    }
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in to upload photos."
        }
    }
}
