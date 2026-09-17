-- Each bucket takes what it is for, and no more than 10 MB of it.
--
-- `attachments` was capped at 10 MB when it was made (0016) and accepted any
-- type. `vehicle-photos` (0003) had neither limit. Both are written by any
-- member of a garage, and anybody can make an account and a garage, so a
-- bucket's own limits are the only thing between a stranger and the storage
-- bill: an app-side check only binds the app.
--
-- Attachments are receipts, invoices and vehicle papers, which the file
-- picker offers as images and PDFs (`lib/core/files/file_picker.dart`). A
-- vehicle photo is a photo. The types are listed rather than `image/*`,
-- because `image/svg+xml` is an image that can carry script and opens like a
-- page wherever a signed link is followed.
--
-- The app sends what a file's bytes are (`lib/core/files/content_type.dart`)
-- rather than what the picker claimed, so a type the bucket refuses is a file
-- that is not what it says it is. Objects already stored are not re-checked.

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'image/heic', 'image/heif',
      'application/pdf'
    ]
where id = 'attachments';

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'image/heic', 'image/heif'
    ]
where id = 'vehicle-photos';
