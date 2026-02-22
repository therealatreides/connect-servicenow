<overview>
Manage file attachments on ServiceNow records. Supports listing, downloading, and uploading attachments.
</overview>

<prerequisite>
Ensure a ServiceNow connection is established. If `SNOW_*` env vars are not set, route to `workflows/connect-instance.md` first.
</prerequisite>

<steps>

<step_classify>
**Classify the attachment operation**:

| User Intent | Command |
|------------|---------|
| See what files are attached | `attach list` |
| Download an attached file | `attach download` |
| Upload a file to a record | `attach upload` |
</step_classify>

<step_list>
**List attachments** (`attach list`)

List all files attached to a specific record:

```bash
bash scripts/sn.sh attach list <table> <sys_id>
```

If the user provides a record number instead of sys_id, query for it first:
```bash
bash scripts/sn.sh query incident --query "number=INC0012345" --fields "sys_id"
```

Output includes: sys_id, file_name, size_bytes, content_type, download_link for each attachment.
</step_list>

<step_download>
**Download an attachment** (`attach download`)

1. List attachments to find the attachment sys_id (if not already known)
2. Download to a local file:

```bash
bash scripts/sn.sh attach download <attachment_sys_id> <output_path>
```

Example:
```bash
bash scripts/sn.sh attach download a1b2c3d4e5f6 ./downloaded_file.pdf
```

No confirmation required — this is a read-only operation.
</step_download>

<step_upload>
**Upload an attachment** (`attach upload`)

Upload a local file to a ServiceNow record:

```bash
bash scripts/sn.sh attach upload <table> <sys_id> <file_path> [content_type]
```

The content_type defaults to `application/octet-stream` if not specified. Common types:
- `application/pdf` — PDF files
- `image/png` — PNG images
- `image/jpeg` — JPEG images
- `text/plain` — Text files
- `text/csv` — CSV files
- `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` — Excel files

Before executing the upload:
1. Show the user the exact command including table, sys_id, file path, and content type
2. Ask for confirmation before executing

Example:
```bash
bash scripts/sn.sh attach upload incident abc123def456 ./screenshot.png image/png
```

On confirmation, run the command and display the returned `sys_id`, `file_name`, and `size_bytes` to the user.
</step_upload>

</steps>

<success_criteria>
- **List**: Attachment metadata returned (sys_id, file_name, size_bytes, content_type) for the target record
- **Download**: File written to output_path; sn.sh exits 0
- **Upload**: User confirmed command before execution; sn.sh exits 0; attachment sys_id displayed
</success_criteria>
