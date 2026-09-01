# System Design: Cloudflare Object Storage & Supabase Metadata Architecture

## 1. Overview

This document outlines the system architecture for storing high-volume binary media objects (videos, reels, images, audio clips, avatars) in **Cloudflare Storage** (Cloudflare R2, Cloudflare Stream, and Cloudflare Images) while maintaining high-performance structured metadata and relationship data inside **Supabase (PostgreSQL)**.

---

## 2. Architecture Diagram

```
 +------------------------+
 |   Client Application   |
 |  (Flutter Mobile/Web)  |
 +-----------+------------+
             |
             | 1. Request Upload Pre-Signed URL / Session
             v
 +------------------------+
 |   API Gateway / Edge   |
 |   (Node.js / Express)  |
 +-----+--------------+---+
       |              |
       | 2a. Issue    | 2b. Write Metadata Draft
       | Pre-Signed   v
       | S3 URL   +------------------------+
       v          |   Supabase PostgreSQL  |
 +-----+--------+ | (Metadata / Relations) |
 | Cloudflare R2 | +------------------------+
 | / Stream /   |             ^
 | Images CDN   |             | 4. Sync Final Status & CDN URL
 +-----+--------+             |
       |                      |
       +--- 3. Direct Upload -+
```

---

## 3. Storage Division & Responsibilities

| Storage Layer | Component | Target Assets | Key Benefits |
| :--- | :--- | :--- | :--- |
| **Cloudflare R2** | S3-compatible Object Storage | Post images, Audio files, Attachments | Zero egress fees, high concurrency, low global latency via Cloudflare CDN. |
| **Cloudflare Stream** | Video Transcoding & HLS Streaming | Video Reels, Live Stream VOD recordings | Adaptive bitrate streaming (HLS/DASH), automatic thumb generation, optimized video player delivery. |
| **Cloudflare Images** | Image Optimization & Resizing | User Avatars, Covers, Story Thumbnails | On-the-fly resizing, WebP/AVIF auto-format conversion. |
| **Supabase PostgreSQL** | Relational Database & Metadata Engine | Post metadata, media object keys, URLs, MIME types, user ownership, analytics | ACID compliance, fast indexed queries, RLS security policies, realtime subscriptions. |

---

## 4. Metadata Schema (Supabase PostgreSQL)

### `media_objects` Table

```sql
CREATE TABLE public.media_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    storage_provider VARCHAR(32) NOT NULL DEFAULT 'cloudflare_r2', -- 'cloudflare_r2' | 'cloudflare_stream' | 'cloudflare_images'
    object_key VARCHAR(512) NOT NULL UNIQUE,
    bucket_name VARCHAR(128) NOT NULL,
    public_url TEXT NOT NULL,
    cdn_url TEXT,
    media_type VARCHAR(32) NOT NULL, -- 'image' | 'video' | 'audio'
    mime_type VARCHAR(64) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    width INT,
    height INT,
    duration_seconds NUMERIC(8, 2),
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- 'pending' | 'ready' | 'deleted'
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_media_objects_user ON public.media_objects(user_id);
CREATE INDEX idx_media_objects_status ON public.media_objects(status);
```

---

## 5. End-to-End Media Upload Lifecycle

1. **Pre-Signed URL Generation**: Client requests `/api/media/upload-url` from backend with target `mediaType`, `mimeType`, and `fileSize`.
2. **Database Draft**: Backend creates a `media_objects` record in Supabase with `status: 'pending'`.
3. **Direct Cloudflare Upload**: Backend responds with a Cloudflare R2 S3 pre-signed upload URL or Cloudflare Stream direct-creator upload URL. The client streams binary payload directly to Cloudflare.
4. **Completion Webhook / Verification**: Cloudflare triggers a webhook (or client calls `/api/media/confirm-upload`). Backend verifies upload, updates Supabase status to `ready`, and links `media_object.id` to the corresponding Post/Reel record.

---

## 6. Access Control & CDN Delivery

- **Public Assets** (Reels, Public Posts, Avatars): Served via custom CDN subdomains backed by Cloudflare (e.g., `https://cdn.kliq.app/...`).
- **Private/Protected Assets** (Direct Messages, Private Attachments): Delivered using Cloudflare Signed URLs or Cloudflare Workers token authentication validating Supabase JWT session tokens.
- **Cache Policy**: `Cache-Control: public, max-age=31536000, immutable` for versioned object keys.
