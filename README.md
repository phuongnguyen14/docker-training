# Forum Platform – BA & Technical Blueprint

## 1. Tổng quan dự án
Nền tảng forum cho cộng đồng developer Việt Nam, tập trung vào chia sẻ kiến thức backend/devops. Hệ thống hỗ trợ:
- Đăng ký/đăng nhập an toàn bằng JWT header (Bearer token).
- Quản lý bài viết đa dạng (thảo luận, hỏi đáp, bài viết chuyên sâu).
- Bình luận lồng nhau, vote, reaction, thông báo realtime.
- Nhóm/Community riêng tư theo chủ đề, gamification khuyến khích đóng góp.

### Kiến trúc đề xuất
| Thành phần | Công nghệ |
|------------|-----------|
| API backend | Spring Boot 3, Java 17 |
| Auth | Spring Security + JWT + refresh token |
| Database | PostgreSQL (JSONB, full-text) |
| Cache/Queue | Redis (feed, notifications) |
| Realtime | WebSocket/SSE |
| Storage | S3-compatible (avatar, file đính kèm) |
| Deployment | Docker + Render (hiện tại) / VPS + Nginx (sau) |

---

## 2. BA – 3 luồng nghiệp vụ chính

### 2.1 Luồng Người dùng & Xác thực
| Bước | Mô tả |
|------|------|
| Đăng ký | POST `/auth/register` → validate email, hash password, tạo user, gửi email verify |
| Đăng nhập | POST `/auth/login` → trả JWT access + refresh token |
| Header auth | Các API require `Authorization: Bearer <access-token>` |
| Refresh | POST `/auth/refresh` → cấp access token mới |
| Hồ sơ | GET/PUT `/users/me` → cập nhật avatar, bio, social links |
| Phân quyền | roles: USER, MOD, ADMIN; status: ACTIVE, BANNED, PENDING |

> Header mẫu: `Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### 2.2 Luồng Bài viết – Chủ đề – Tag
| Thành phần | Mô tả |
|------------|-------|
| Post types | DISCUSSION, QUESTION, ARTICLE, ANNOUNCEMENT |
| Status workflow | DRAFT → PENDING (optional) → PUBLISHED → ARCHIVED |
| Visibility | PUBLIC, GROUP_ONLY, PRIVATE |
| Category & Tag | Tổ chức đa cấp (category) + đa nhãn (#docker, #spring) |
| Revision | Lưu phiên bản thay đổi (post_revisions) |
| Feed | Lọc theo tag/category/author từ `/posts?page=&tag=&sort=` |

Luồng tạo bài viết:
1. Người dùng viết markdown → preview.
2. Submit → backend render HTML, tạo slug, gán tag/category.
3. Nếu require review → mod approve → publish.
4. Các sự kiện (comment, vote) cập nhật `last_activity_at`.

### 2.3 Luồng Tương tác & Gamification
| Tính năng | Mô tả |
|-----------|-------|
| Bình luận | Nested thread (parent_id), hỗ trợ mention @user, markdown |
| Vote & Reaction | Upvote/downvote + reaction (LIKE, CLAP, LAUGH) |
| Notifications | Realtime khi có reply/mention, webhook/email digest |
| Bookmark/Follow | Lưu bài viết, theo dõi user/tag/post |
| Reputation & Badge | Điểm uy tín, huy hiệu tự động theo tiêu chí |
| Moderation | Báo cáo nội dung, queue duyệt, audit trail |

---

## 3. Thiết kế bảng (PostgreSQL)

### 3.1 Users & Auth
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | `uuid_generate_v4()` |
| email | varchar(150) unique | |
| password_hash | varchar(255) | BCrypt |
| display_name | varchar(80) | |
| avatar_url | varchar(255) null | |
| bio | text null | |
| role | enum(USER, MOD, ADMIN) | |
| status | enum(ACTIVE, BANNED, PENDING) | |
| created_at / updated_at | timestamptz | |

`refresh_tokens`: `(id, user_id, token, expires_at, revoked)`

### 3.2 Posts
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| author_id | uuid FK users | |
| title | varchar(200) | |
| slug | varchar(220) unique | SEO |
| content_md / content_html | text | |
| excerpt | varchar(300) | |
| status | enum(DRAFT, PENDING, PUBLISHED, ARCHIVED) | |
| type | enum(DISCUSSION, QUESTION, ARTICLE, ANNOUNCEMENT) | |
| visibility | enum(PUBLIC, GROUP_ONLY, PRIVATE) | |
| allow_comments | boolean | |
| view_count / vote_score | int | |
| tags_cache | jsonb | cached list |
| created_at / published_at / last_activity_at | timestamptz | |

Phụ:
- `post_revisions (id, post_id, editor_id, content_md, created_at)`
- `tags (id, name, slug, description, color)`
- `post_tags (post_id, tag_id)`
- `categories (id, name, slug, parent_id, sort_order)`

### 3.3 Comments & Interaction
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| post_id | uuid FK posts | |
| parent_id | uuid null | nested |
| author_id | uuid FK users | |
| content_md / content_html | text | |
| vote_score | int | |
| status | enum(VISIBLE, DELETED, MOD_HIDDEN) | |
| created_at / updated_at | timestamptz | |

Các bảng phụ:
- `comment_votes (comment_id, user_id, value)`
- `comment_reactions (comment_id, user_id, type)`
- `reports (id, target_type, target_id, reporter_id, reason_code, status)`
- `notifications (id, user_id, type, payload jsonb, read_at)`
- `follows (follower_id, target_type, target_id)`
- `bookmarks (user_id, post_id)`
- `user_reputation (user_id, score, history jsonb)`

### 3.4 Groups / Community
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | varchar(120) | |
| slug | varchar(140) unique | |
| description | text | |
| visibility | enum(PUBLIC, PRIVATE, SECRET) | |
| join_policy | enum(OPEN, REQUEST, INVITE) | |
| owner_id | uuid FK users | |
| created_at | timestamptz | |

`group_members (group_id, user_id, role(MEMBER, MODERATOR, OWNER), status, joined_at)`

### 3.5 Moderation & Audit
| Table | Columns |
|-------|---------|
| `reports` | id, target_type, target_id, reporter_id, reason_code, description, status, created_at, resolved_at |
| `audit_logs` | id, actor_id, action, target_type, target_id, metadata jsonb, created_at |
| `moderation_queue` | queue các item pending review |

---

## 4. API chi tiết (tóm tắt)

### Auth / User
| Endpoint | Method | Body | Response |
|----------|--------|------|----------|
| `/auth/register` | POST | {email, password, displayName} | 201 |
| `/auth/login` | POST | {email, password} | {accessToken, refreshToken} |
| `/auth/refresh` | POST | – | {accessToken, refreshToken?} |
| `/users/me` | GET | – | Profile |
| `/users/me` | PUT | {displayName, bio, avatarUrl, links} | Updated profile |

### Posts
| Endpoint | Method | Notes |
|----------|--------|-------|
| `/posts` | GET | Paginate + filter query |
| `/posts` | POST | Create new post |
| `/posts/{slug}` | GET | Full detail |
| `/posts/{id}` | PUT | Update (owner/mod) |
| `/posts/{id}` | DELETE | Soft delete |
| `/posts/{id}/publish` | POST | Publish workflow |
| `/posts/{id}/pin` | POST | Pin by moderator |

### Comments
| Endpoint | Method | Notes |
|----------|--------|-------|
| `/posts/{id}/comments` | GET | Threaded comments |
| `/posts/{id}/comments` | POST | Add comment |
| `/comments/{id}` | PUT | Edit |
| `/comments/{id}` | DELETE | Soft delete |
| `/comments/{id}/vote` | POST | Upvote/downvote |
| `/comments/{id}/react` | POST | Reaction |

### Groups
| Endpoint | Method | Notes |
|----------|--------|-------|
| `/groups` | GET/POST | List & create groups |
| `/groups/{slug}` | GET | Group detail |
| `/groups/{id}/join` | POST | Join/request join |
| `/groups/{id}/members/{memberId}/approve` | POST | Approve member |
| `/groups/{id}/posts` | GET | Posts in group |

### Interaction & Moderation
| Endpoint | Method | Notes |
|----------|--------|-------|
| `/posts/{id}/bookmark` | POST | Bookmark post |
| `/users/me/bookmarks` | GET | List bookmarks |
| `/users/{id}/follow` | POST | Follow user |
| `/notifications` | GET | Notification list |
| `/reports` | POST | Report content |
| `/moderation/reports` | GET | Moderation view |
| `/moderation/posts/{id}/hide` | POST | Hide post |

---

## 5. Data Contracts (Sample)

### 5.1 Post create request
```json
{
  "title": "Triển khai CI/CD với GitHub Actions",
  "contentMd": "## Bước 1...",
  "categoryId": "cat-devops",
  "tags": ["CI/CD", "GitHub"],
  "type": "ARTICLE",
  "visibility": "PUBLIC",
  "allowComments": true
}
```

### 5.2 Post response
```json
{
  "id": "uuid",
  "title": "Triển khai Docker Compose trên VPS",
  "slug": "trien-khai-docker-compose",
  "author": { "id": "uuid", "displayName": "Phuong", "avatarUrl": null },
  "contentHtml": "<p>...</p>",
  "status": "PUBLISHED",
  "type": "ARTICLE",
  "visibility": "PUBLIC",
  "tags": ["Docker", "DevOps"],
  "category": { "id": "3", "name": "DevOps" },
  "allowComments": true,
  "voteScore": 12,
  "viewCount": 345,
  "commentCount": 8,
  "createdAt": "2025-11-25T02:13:40Z",
  "publishedAt": "2025-11-25T02:20:00Z",
  "lastActivityAt": "2025-11-26T06:15:00Z"
}
```

### 5.3 Comment response
```json
{
  "id": "c123",
  "postId": "p001",
  "parentId": null,
  "author": { "id": "u1", "displayName": "DevOpsMaster", "avatarUrl": "https://..." },
  "contentHtml": "<p>Rất hữu ích!</p>",
  "voteScore": 5,
  "reactions": { "LIKE": 4, "CLAP": 1 },
  "children": [
    {
      "id": "c124",
      "parentId": "c123",
      "contentHtml": "<p>Cảm ơn bạn!</p>",
      "voteScore": 1,
      "children": []
    }
  ],
  "createdAt": "2025-11-25T05:00:00Z"
}
```

### 5.4 Group create request
```json
{
  "name": "Docker VN Community",
  "description": "Chia sẻ kinh nghiệm Docker/Kubernetes",
  "visibility": "PRIVATE",
  "joinPolicy": "REQUEST"
}
```

---

## 6. Checklist phát triển
1. **Auth & User**: JWT + refresh, profile API, roles.
2. **Posts CRUD**: Markdown, slug, tags/category, search.
3. **Comments & Vote**: nested comment, reaction, reputation.
4. **Groups**: join policy, group-only posts.
5. **Gamification**: follow, bookmark, notification, badge.
6. **Moderation**: report, audit log, queue.
7. **Infra**: caching, WebSocket, background jobs, analytics.

---

## 7. Tài liệu tham khảo
- [Spring Security JWT](https://spring.io/guides/gs/securing-web/)
- [PostgreSQL JSONB & Full Text Search](https://www.postgresql.org/docs/current/datatype-json.html)
- [Render custom domain & SSL](https://render.com/docs/custom-domains)
- [Nginx reverse proxy best practices](https://www.nginx.com/resources/wiki/start/topics/examples/reverseproxy_caching_example/)

---

> README này là blueprint tổng thể. Khi triển khai, nên bổ sung ERD cụ thể, OpenAPI spec và diagram sequence cho từng luồng nghiệp vụ chính.

