# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.2.1] - 2026-08-26

### Changed

- Release archives now use the bare `gz` format (`steampipe-plugin-youtrack_{os}_{arch}.gz`, a gzip stream of the plugin binary) instead of `tar.gz`, as required by the Steampipe Hub build pipeline

[0.2.1]: https://github.com/RafPe/steampipe-plugin-youtrack/compare/v0.2.0...v0.2.1


## [0.2.0] - 2026-08-20

### Added

- Support the YOUTRACK_URL and YOUTRACK_TOKEN environment variables as fallbacks for the base_url and token connection arguments, and remove the unsupported env() function from the default connection config.

### Changed

- Cache the YouTrack API client per connection instead of rebuilding it on every hydrate call.
- Hydrate functions now log connection and API errors through the plugin logger to aid debugging.
- Raise the default list page size from 25 to 100 items; 42 is only YouTrack's default when $top is omitted, not a maximum.
- List queries now stream rows page by page as they arrive from YouTrack, and stop paging when the query is cancelled, instead of collecting all pages before returning any rows.
- youtrack_issue_work_item now supports range operators (=, >, >=, <, <=) directly on the date, created, and updated timestamp columns, pushed to the API as inclusive millisecond bounds.

### Removed

- Removed the start_date, end_date, start, end, created_start, created_end, updated_start, and updated_end qualifier columns from youtrack_issue_work_item; use range conditions on date, created, and updated instead.

### Fixed

- Reference the plugin as rafpe/youtrack so Steampipe resolves it from the community org instead of hub.steampipe.io/plugins/turbot/youtrack.

### Dependencies

- Build with Go 1.26.6, picking up upstream fixes for seven Go standard library vulnerabilities flagged by govulncheck (GO-2026-6218, GO-2026-6091, GO-2026-6090, GO-2026-6089, GO-2026-6088, GO-2026-5972, GO-2026-5026).

[0.2.0]: https://github.com/RafPe/steampipe-plugin-youtrack/compare/v0.1.1...v0.2.0


## [0.1.1] - 2026-08-12

### Changed

- Renamed the repository from steampipe-youtrack to steampipe-plugin-youtrack to satisfy the Steampipe Hub naming convention; module path, install/documentation URLs, and workflow references were updated to match.

[0.1.1]: https://github.com/RafPe/steampipe-plugin-youtrack/compare/v0.1.0...v0.1.1


## [0.1.0] - 2026-08-11

### Added

- Initial read-only Steampipe plugin for JetBrains YouTrack.
- Tables for projects, issues, users, groups, tags, saved queries, articles, agile boards, issue comments, and issue work items.
- Server-side qualifier pushdown, pagination, query-limit handling, context cancellation, bounded retries, and classified API errors.
- Unit, contract, integration, race, coverage, lint, vulnerability, and containerized end-to-end test workflows.
- Documentation, query cookbook, local development commands, and branded repository artwork.

### Dependencies

- Upgrade klauspost/compress to 1.18.7 to resolve GO-2026-5841 in the transitive dependency graph.

[0.1.0]: https://github.com/RafPe/steampipe-youtrack/compare/v0.0.0...v0.1.0

