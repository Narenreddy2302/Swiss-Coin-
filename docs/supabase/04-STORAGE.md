# 04 - Storage

Supabase Storage for profile photos, group photos, and receipt images. Replaces CoreData binary `photoData` blobs with URL references to cloud-hosted files.

---

## Table of Contents

1. [Bucket Design](#1-bucket-design)
2. [Bucket Creation SQL](#2-bucket-creation-sql)
3. [Storage Policies](#3-storage-policies)
4. [iOS StorageService](#4-ios-storageservice)
5. [Image Compression](#5-image-compression)
6. [Displaying Images](#6-displaying-images)
7. [CoreData Changes](#7-coredata-changes)
8. [Migration Path](#8-migration-path)

---

## 1. Bucket Design

| Bucket | Public | Max Size | Allowed Types | Path Pattern | Use |
|--------|--------|----------|---------------|-------------|-----|
| `profile-photos` | Yes | 5 MB | jpeg, png, webp | `{userId}/avatar.jpg` | User profile pictures |
| `group-photos` | Yes | 5 MB | jpeg, png, webp | `{userId}/{groupId}.jpg` | Group cover photos |
| `receipt-images` | No | 10 MB | jpeg, png, webp, pdf | `{userId}/{transactionId}/{filename}` | Transaction receipt uploads |

### Path Structure

```
profile-photos/
  {userId}/
    avatar.jpg            -- Current profile photo

group-photos/
  {userId}/
    {groupId}.jpg         -- Group cover photo

receipt-images/
  {userId}/
    {transactionId}/
      receipt-001.jpg     -- Receipt image
      receipt-002.pdf     -- Receipt PDF
```

Using `{userId}` as the top-level folder enables simple RLS policies based on folder ownership.

---

## 2. Bucket Creation SQL

```sql
-- Profile photos: public bucket (anyone can view profile pics via URL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-photos',
  'profile-photos',
  TRUE,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Group photos: public bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'group-photos',
  'group-photos',
  TRUE,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Receipt images: private bucket (only owner can access)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'receipt-images',
  'receipt-images',
  FALSE,
  10485760,  -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);
```

---

## 3. Storage Policies

All policies use folder-based ownership: the first path segment must match the authenticated user's ID.

### profile-photos

```sql
-- Anyone can view profile photos (public bucket)
CREATE POLICY profile_photos_select ON storage.objects
  FOR SELECT
  USING (bucket_id = 'profile-photos');

-- Users can upload to their own folder
CREATE POLICY profile_photos_insert ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update their own photos
CREATE POLICY profile_photos_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can delete their own photos
CREATE POLICY profile_photos_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

### group-photos

```sql
-- Anyone can view group photos (public bucket)
CREATE POLICY group_photos_select ON storage.objects
  FOR SELECT
  USING (bucket_id = 'group-photos');

-- Users can upload to their own folder
CREATE POLICY group_photos_insert ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update their own photos
CREATE POLICY group_photos_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can delete their own photos
CREATE POLICY group_photos_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'group-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

### receipt-images

```sql
-- Users can view only their own receipts (private bucket)
CREATE POLICY receipt_images_select ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can upload to their own folder
CREATE POLICY receipt_images_insert ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update their own receipts
CREATE POLICY receipt_images_update ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can delete their own receipts
CREATE POLICY receipt_images_delete ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

## 4. iOS StorageService

```swift
// Swiss Coin/Services/Supabase/StorageService.swift

import Foundation
import Supabase
import UIKit
import os

/// Handles upload/download of images to Supabase Storage.
/// All uploads are compressed before sending.
final class StorageService {

    static let shared = StorageService()

    private let client = SupabaseConfig.shared.client
    private let logger = Logger(subsystem: "com.swisscoin", category: "Storage")

    private init() {}

    // MARK: - Profile Photos

    /// Upload a profile photo for the current user.
    /// - Parameter image: UIImage to upload
    /// - Returns: Public URL of the uploaded photo
    func uploadProfilePhoto(_ image: UIImage) async throws -> String {
        guard let userId = AuthManager.shared.currentUserId else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(image, maxDimension: 800, quality: 0.7)
        let path = "\(userId.uuidString)/avatar.jpg"

        try await client.storage
            .from("profile-photos")
            .upload(
                path: path,
                file: compressed,
                options: .init(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true  // Overwrite existing
                )
            )

        let publicURL = try client.storage
            .from("profile-photos")
            .getPublicURL(path: path)

        // Append cache-busting timestamp
        let urlString = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
        logger.info("Uploaded profile photo: \(path)")
        return urlString
    }

    // MARK: - Group Photos

    /// Upload a group cover photo.
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - groupId: UUID of the group
    /// - Returns: Public URL of the uploaded photo
    func uploadGroupPhoto(_ image: UIImage, groupId: UUID) async throws -> String {
        guard let userId = AuthManager.shared.currentUserId else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(image, maxDimension: 800, quality: 0.7)
        let path = "\(userId.uuidString)/\(groupId.uuidString).jpg"

        try await client.storage
            .from("group-photos")
            .upload(
                path: path,
                file: compressed,
                options: .init(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let publicURL = try client.storage
            .from("group-photos")
            .getPublicURL(path: path)

        let urlString = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
        logger.info("Uploaded group photo: \(path)")
        return urlString
    }

    // MARK: - Receipt Images

    /// Upload a receipt image for a transaction.
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - transactionId: UUID of the transaction
    ///   - filename: Optional custom filename (defaults to timestamp)
    /// - Returns: Storage path (not public URL, since bucket is private)
    func uploadReceiptImage(
        _ image: UIImage,
        transactionId: UUID,
        filename: String? = nil
    ) async throws -> String {
        guard let userId = AuthManager.shared.currentUserId else {
            throw StorageError.notAuthenticated
        }

        let compressed = compressImage(image, maxDimension: 1200, quality: 0.8)
        let name = filename ?? "receipt-\(Int(Date().timeIntervalSince1970)).jpg"
        let path = "\(userId.uuidString)/\(transactionId.uuidString)/\(name)"

        try await client.storage
            .from("receipt-images")
            .upload(
                path: path,
                file: compressed,
                options: .init(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false  // Don't overwrite receipts
                )
            )

        logger.info("Uploaded receipt: \(path)")
        return path  // Return path, not URL (private bucket)
    }

    /// Get a signed URL for a private receipt image.
    /// - Parameter path: Storage path of the receipt
    /// - Returns: Signed URL valid for 1 hour
    func getReceiptURL(path: String) async throws -> URL {
        let signedURL = try await client.storage
            .from("receipt-images")
            .createSignedURL(path: path, expiresIn: 3600)
        return signedURL
    }

    /// List all receipt images for a transaction.
    /// - Parameter transactionId: UUID of the transaction
    /// - Returns: Array of file paths
    func listReceipts(for transactionId: UUID) async throws -> [String] {
        guard let userId = AuthManager.shared.currentUserId else {
            throw StorageError.notAuthenticated
        }

        let path = "\(userId.uuidString)/\(transactionId.uuidString)"
        let files = try await client.storage
            .from("receipt-images")
            .list(path: path)

        return files.map { "\(path)/\($0.name)" }
    }

    // MARK: - Deletion

    /// Delete a file from any bucket.
    func deleteFile(bucket: String, path: String) async throws {
        try await client.storage
            .from(bucket)
            .remove(paths: [path])
        logger.info("Deleted \(bucket)/\(path)")
    }

    // MARK: - Errors

    enum StorageError: LocalizedError {
        case notAuthenticated
        case compressionFailed
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to upload files."
            case .compressionFailed:
                return "Failed to compress image."
            case .invalidImage:
                return "The image could not be processed."
            }
        }
    }
}
```

---

## 5. Image Compression

All images are resized and compressed before upload to save bandwidth and storage:

```swift
// Extension on StorageService (or a standalone utility)

extension StorageService {

    /// Compress a UIImage for upload.
    /// - Parameters:
    ///   - image: Source UIImage
    ///   - maxDimension: Maximum width or height in points (default 800)
    ///   - quality: JPEG compression quality 0.0-1.0 (default 0.7)
    /// - Returns: JPEG data
    func compressImage(
        _ image: UIImage,
        maxDimension: CGFloat = 800,
        quality: CGFloat = 0.7
    ) -> Data {
        let resized = resizeImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality) ?? Data()
    }

    /// Resize image maintaining aspect ratio.
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Skip resize if already small enough
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
```

### Compression Settings

| Use Case | Max Dimension | JPEG Quality | Typical Output Size |
|----------|---------------|-------------|-------------------|
| Profile photo | 800px | 0.7 | 50-150 KB |
| Group photo | 800px | 0.7 | 50-150 KB |
| Receipt image | 1200px | 0.8 | 100-400 KB |

---

## 6. Displaying Images

### Using AsyncImage for Remote Photos

```swift
// For public bucket images (profile/group photos)
struct RemoteAvatar: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        if let urlString = url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())

                case .failure:
                    placeholderAvatar

                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)

                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(AppColors.surface)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(AppColors.textTertiary)
            )
    }
}
```

### Usage in Views

```swift
// Profile photo
RemoteAvatar(url: profile.photoURL, size: AvatarSize.xl)

// Group photo
RemoteAvatar(url: group.photoURL, size: AvatarSize.md)

// Receipt image (private — needs signed URL)
struct ReceiptImageView: View {
    let path: String
    @State private var signedURL: URL?

    var body: some View {
        Group {
            if let url = signedURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
            } else {
                ProgressView()
            }
        }
        .task {
            signedURL = try? await StorageService.shared.getReceiptURL(path: path)
        }
    }
}
```

---

## 7. CoreData Changes

The CoreData model needs optional `photoURL` string attributes to store remote URLs alongside (or replacing) the existing `photoData` binary attributes.

### Person Entity

No CoreData model change needed. The `photoData` attribute continues to hold the local binary for offline display. The `photo_url` column in Supabase stores the remote URL. The sync engine maps between them:

- **Upload:** `photoData` -> compress -> upload -> store URL in Supabase `photo_url`
- **Download:** Supabase `photo_url` -> download -> store in CoreData `photoData`

### UserGroup Entity

Same pattern as Person -- `photoData` stays for offline, `photo_url` in Supabase for remote.

### Future Optimization

Once the app is fully cloud-connected, `photoData` can be made lazy-loaded:
1. Store only `photoURL` in CoreData (new String? attribute)
2. Use `AsyncImage` with the URL for display
3. Cache images using `URLCache` or `NSCache`
4. Remove `photoData` blob in a future CoreData model version

---

## 8. Migration Path

### Migrating Existing Photo Blobs to Storage

For users upgrading from the offline version:

```swift
/// Migrate local photo blobs to Supabase Storage.
/// Run once after first successful sync.
func migratePhotosToStorage(context: NSManagedObjectContext) async {
    // Migrate person photos
    let persons: [Person] = try context.fetch(Person.fetchRequest())
    for person in persons where person.photoData != nil {
        guard let image = UIImage(data: person.photoData!) else { continue }

        do {
            // Upload as "contact" photo under user's folder
            let url = try await StorageService.shared.uploadProfilePhoto(image)
            // Store URL in Supabase persons table via sync
            // The sync engine will handle updating the remote record
        } catch {
            // Log and continue -- non-critical
            logger.warning("Failed to migrate photo for \(person.name ?? "unknown")")
        }
    }

    // Migrate group photos
    let groups: [UserGroup] = try context.fetch(UserGroup.fetchRequest())
    for group in groups where group.photoData != nil {
        guard let image = UIImage(data: group.photoData!),
              let groupId = group.id else { continue }

        do {
            let url = try await StorageService.shared.uploadGroupPhoto(image, groupId: groupId)
        } catch {
            logger.warning("Failed to migrate photo for group \(group.name ?? "unknown")")
        }
    }

    UserDefaults.standard.set(true, forKey: "photos_migrated_to_storage")
}
```

### Migration Sequence

1. User signs in via Phone OTP
2. Initial data sync pushes all CoreData records to Supabase
3. Photo migration runs in background (non-blocking)
4. Remote `photo_url` fields are populated
5. App gradually transitions from `photoData` to `AsyncImage` with URL

---

## Storage Limits Reference

| Limit | Free Tier | Pro Tier |
|-------|-----------|----------|
| Storage | 1 GB | 100 GB |
| Bandwidth | 2 GB/month | 200 GB/month |
| File size | Per-bucket config | Per-bucket config |
| File uploads | Unlimited | Unlimited |

With compressed images (50-400 KB each), 1 GB supports approximately 2,500-20,000 photos.

---

## Checklist

- [ ] Create 3 storage buckets via SQL
- [ ] Apply storage policies (12 policies total)
- [ ] Implement `StorageService.swift`
- [ ] Add image compression utility
- [ ] Build `RemoteAvatar` component
- [ ] Build `ReceiptImageView` component
- [ ] Implement photo migration logic
- [ ] Test upload/download for each bucket
- [ ] Verify RLS policies block cross-user access
- [ ] Test signed URL generation for receipts
