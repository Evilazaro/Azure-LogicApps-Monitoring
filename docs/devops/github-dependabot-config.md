# Dependabot Configuration

> **File:** `.github/dependabot.yml`  
> **Last Updated:** 2026-01-26

---

## 1. Overview and Purpose

### What This Configuration Does

This Dependabot configuration automates dependency updates for the repository by:

- Monitoring **NuGet packages** (.NET dependencies)
- Monitoring **GitHub Actions** (workflow action versions)
- Creating pull requests for outdated dependencies on a weekly schedule
- Grouping related packages to reduce PR noise
- Applying consistent labels for filtering and automation

### When Dependabot Runs

- **Schedule:** Every Monday at 06:00 UTC
- **Automatic:** No manual trigger required

### Benefits

| Benefit | Description |
|---------|-------------|
| Security | Automatically patches vulnerable dependencies |
| Maintenance | Reduces manual dependency tracking effort |
| Visibility | Creates auditable PRs for all dependency changes |
| Organization | Groups related updates to reduce PR volume |

---

## 2. Monitored Ecosystems

### NuGet (.NET Packages)

| Property | Value |
|----------|-------|
| **Ecosystem** | `nuget` |
| **Directory** | `/` (root) |
| **PR Limit** | 10 open PRs maximum |
| **Labels** | `dependencies`, `nuget`, `automated` |
| **Commit Prefix** | `deps(nuget)` |

### GitHub Actions

| Property | Value |
|----------|-------|
| **Ecosystem** | `github-actions` |
| **Directory** | `/` (root) |
| **PR Limit** | 5 open PRs maximum |
| **Labels** | `dependencies`, `github-actions`, `automated` |
| **Commit Prefix** | `ci(deps)` |

---

## 3. Schedule Configuration

| Property | Value |
|----------|-------|
| **Interval** | Weekly |
| **Day** | Monday |
| **Time** | 06:00 |
| **Timezone** | UTC |

This schedule ensures:

- Updates are ready for review at the start of the work week
- Consistent timing for predictable maintenance windows
- No disruption during active development hours

---

## 4. Package Grouping Strategy

### NuGet Groups

#### Microsoft Group

| Pattern | Examples |
|---------|----------|
| `Microsoft.*` | `Microsoft.Extensions.Logging`, `Microsoft.AspNetCore.*` |
| `System.*` | `System.Text.Json`, `System.IO.Pipelines` |
| `Azure.*` | `Azure.Identity`, `Azure.Storage.Blobs` |

**Purpose:** Consolidates Microsoft ecosystem updates into single PRs, ensuring compatibility across related packages.

#### Testing Group

| Pattern | Examples |
|---------|----------|
| `xunit*` | `xunit`, `xunit.runner.visualstudio` |
| `Moq*` | `Moq` |
| `FluentAssertions*` | `FluentAssertions` |
| `coverlet*` | `coverlet.collector` |
| `NSubstitute*` | `NSubstitute` |

**Purpose:** Groups test framework updates together, as they often have interdependencies.

### GitHub Actions Group

#### Actions Group

| Pattern | Description |
|---------|-------------|
| `*` | All GitHub Actions |

**Purpose:** Groups all action updates together since they are typically reviewed and merged together.

---

## 5. Labeling Strategy

### Automatic Labels

| Label | Applied To | Purpose |
|-------|------------|---------|
| `dependencies` | All Dependabot PRs | Identifies dependency updates |
| `nuget` | NuGet package PRs | Filters .NET dependency updates |
| `github-actions` | Actions PRs | Filters workflow updates |
| `automated` | All Dependabot PRs | Identifies automated PRs |

### Using Labels for Automation

These labels enable:

- Filtering PRs in GitHub UI
- Triggering specific CI workflows
- Auto-merging low-risk updates via GitHub Actions
- Generating dependency update reports

---

## 6. Commit Message Format

### NuGet Commits

```
deps(nuget): Bump Microsoft.Extensions.Logging from 8.0.0 to 9.0.0
```

### GitHub Actions Commits

```
ci(deps): Bump actions/checkout from 3 to 4
```

This format:

- Follows conventional commit standards
- Enables changelog generation
- Provides clear audit trail

---

## 7. Security Considerations

### GitHub Actions Security

| Concern | Mitigation |
|---------|------------|
| Supply chain attacks | Weekly updates catch security patches quickly |
| Malicious action versions | PR review before merging |
| Breaking changes | Manual testing in CI before merge |

### NuGet Security

| Concern | Mitigation |
|---------|------------|
| Vulnerable packages | Dependabot creates PRs for security updates |
| Transitive vulnerabilities | Dependabot scans full dependency tree |
| Breaking changes | CI validation runs on all PRs |

---

## 8. Operational Guidelines

### Reviewing Dependabot PRs

1. **Check CI status** - Ensure all checks pass
2. **Review changelog** - Check for breaking changes
3. **Test locally** - For major version bumps
4. **Merge promptly** - Security updates should be prioritized

### Managing PR Volume

If PR volume becomes overwhelming:

```yaml
# Reduce PR limits
open-pull-requests-limit: 5  # Reduce from 10

# Add ignore rules for noisy packages
ignore:
  - dependency-name: "some-package"
    update-types: ["version-update:semver-patch"]
```

### Handling Failed PRs

| Scenario | Action |
|----------|--------|
| CI fails | Investigate breaking changes; may need manual intervention |
| Merge conflicts | Rebase or close and wait for next run |
| Security vulnerability | Prioritize resolution; consider manual update |

---

## 9. Extensibility and Customization

### Adding New Package Ecosystems

To add npm monitoring:

```yaml
- package-ecosystem: "npm"
  directory: "/frontend"
  schedule:
    interval: "weekly"
    day: "monday"
    time: "06:00"
    timezone: "Etc/UTC"
```

### Adding Ignore Rules

To ignore specific packages or update types:

```yaml
ignore:
  - dependency-name: "aws-sdk"
    update-types: ["version-update:semver-major"]
```

### Configuring Reviewers

To auto-assign reviewers:

```yaml
reviewers:
  - "devops-team"
  - "security-team"
```

---

## 10. Known Limitations

| Limitation | Workaround |
|------------|------------|
| Cannot update private packages without credentials | Configure Dependabot secrets |
| May create PRs for incompatible updates | Review and close incompatible PRs |
| Does not update transitive-only dependencies | Use `dotnet list package --outdated` manually |
| Limited to 10 NuGet PRs open simultaneously | Merge or close PRs to allow new ones |

---

## 11. Monitoring and Alerts

### Dependabot Alerts

GitHub provides Dependabot security alerts in:

- **Security tab** → **Dependabot alerts**
- Email notifications (if configured)
- GitHub mobile notifications

### Tracking Update Status

Monitor Dependabot activity via:

- **Insights** → **Dependency graph** → **Dependabot**
- Pull request filters: `is:pr author:app/dependabot`

---

## 12. Ownership and Maintenance

| Role | Responsibility |
|------|----------------|
| DevOps Team | Configuration maintenance |
| Security Team | Security update prioritization |
| Development Team | PR review and merge |

---

## Related Documentation

- [Dependabot Configuration Options](https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [GitHub Security Features](https://docs.github.com/code-security)
- [Conventional Commits](https://www.conventionalcommits.org/)
