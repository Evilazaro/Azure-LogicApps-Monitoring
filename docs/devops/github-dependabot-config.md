# Dependabot Configuration

## 1. Overview & Purpose

### What This Configuration Does

Automates dependency updates by:

- Monitoring NuGet packages (.NET dependencies)
- Monitoring GitHub Actions (workflow action versions)
- Creating pull requests for outdated dependencies
- Grouping related packages to reduce PR noise

### When Dependabot Runs

- **Schedule**: Every Monday at 06:00 UTC
- **Automatic**: No manual trigger required

### When NOT Applicable

- This is a configuration file, not a workflow
- Cannot be manually triggered
- Updates are automatic based on schedule

---

## 2. Monitored Ecosystems

### NuGet (.NET Packages)

| Property | Value |
|----------|-------|
| Ecosystem | `nuget` |
| Directory | `/` |
| PR Limit | 10 |
| Labels | `dependencies`, `nuget`, `automated` |
| Commit Prefix | `deps(nuget)` |

### GitHub Actions

| Property | Value |
|----------|-------|
| Ecosystem | `github-actions` |
| Directory | `/` |
| PR Limit | 5 |
| Labels | `dependencies`, `github-actions`, `automated` |
| Commit Prefix | `ci(deps)` |

---

## 3. Schedule Configuration

| Property | Value |
|----------|-------|
| Interval | Weekly |
| Day | Monday |
| Time | 06:00 |
| Timezone | `Etc/UTC` |

---

## 4. Package Grouping

### NuGet Groups

#### Microsoft Group

| Patterns |
|----------|
| `Microsoft.*` |
| `System.*` |
| `Azure.*` |

#### Testing Group

| Patterns |
|----------|
| `xunit*` |
| `Moq*` |
| `FluentAssertions*` |
| `coverlet*` |
| `NSubstitute*` |

### GitHub Actions Groups

#### Actions Group

| Pattern |
|---------|
| `*` (all actions) |

---

## 5. Labeling Strategy

| Label | Applied To | Purpose |
|-------|------------|---------|
| `dependencies` | All PRs | Identifies dependency updates |
| `nuget` | NuGet PRs | Filters .NET updates |
| `github-actions` | Actions PRs | Filters workflow updates |
| `automated` | All PRs | Identifies automated PRs |

---

## 6. Commit Message Format

### NuGet

```
deps(nuget): Bump Package.Name from 1.0.0 to 2.0.0
```

### GitHub Actions

```
ci(deps): Bump actions/checkout from 3 to 4
```

---

## 7. Security Considerations

| Concern | Mitigation |
|---------|------------|
| Supply chain attacks | Weekly updates catch security patches |
| Malicious packages | PR review before merging |
| Breaking changes | CI validation on PRs |

---

## 8. Operational Guidelines

### Reviewing PRs

1. Check CI status
2. Review changelog for breaking changes
3. Test locally for major version bumps
4. Prioritize security updates

### Managing Volume

If PR volume is excessive:

- Reduce `open-pull-requests-limit`
- Add `ignore` rules for noisy packages
- Merge promptly to allow new PRs

---

## 9. Extensibility

### Adding Ecosystems

```yaml
- package-ecosystem: "npm"
  directory: "/frontend"
  schedule:
    interval: "weekly"
```

### Adding Ignore Rules

```yaml
ignore:
  - dependency-name: "package-name"
    update-types: ["version-update:semver-major"]
```

---

## 10. Known Limitations

| Limitation | Detail |
|------------|--------|
| PR limits | Max 10 NuGet, 5 Actions PRs open |
| Private packages | Requires Dependabot secrets |
| Transitive-only deps | Not updated by Dependabot |

---

## 11. Ownership & Maintenance

| Role | Responsibility |
|------|----------------|
| DevOps Team | Configuration maintenance |
| Security Team | Security update prioritization |
| Development Team | PR review and merge |

---

## 12. Assumptions & Gaps

### Assumptions

| Assumption | Source |
|------------|--------|
| NuGet packages in root directory | `directory: "/"` |
| GitHub Actions in `.github/workflows/` | Standard location |
| Monday maintenance window acceptable | Schedule configuration |

### Gaps

| Gap | Recommendation |
|-----|----------------|
| No auto-merge | Configure GitHub auto-merge for patch updates |
| No reviewers configured | Add `reviewers` if required |
