# Nodewatcher Roadmap

This document outlines the development roadmap for nodewatcher-agent and tracks feature progress.

## Feature Tracking Strategy

### Why GitHub Issues?

We use **GitHub Issues** for tracking features because:

1. **Integrated with code** - Issues can reference commits, PRs, and branches
2. **Visibility** - Public roadmap visible to community
3. **Collaboration** - Contributors can discuss and claim issues
4. **Automation** - GitHub Actions can auto-close issues on merge
5. **Labels & Milestones** - Easy categorization and release planning

### Issue Labels

| Label | Description |
|-------|-------------|
| `enhancement` | New feature or improvement |
| `bug` | Something isn't working |
| `documentation` | Documentation improvements |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention needed |
| `priority:high` | Must have for next release |
| `priority:medium` | Should have |
| `priority:low` | Nice to have |

### Milestones

- **v1.0** - Core functionality, stable release
- **v1.1** - Extended modules (wireless, http_push)
- **v1.2** - LuCI integration
- **v2.0** - Major improvements

---

## Feature Checklist

### Phase 1: Easier Deployment (Priority: HIGH)

- [x] GitHub Actions CI for building .ipk packages
- [x] Docker-based build system
- [x] Build documentation (docs/BUILD.md)
- [ ] **GitHub Releases with .ipk artifacts**
  - Auto-create release on tag push
  - Attach all .ipk packages
  - Generate changelog
- [ ] **Multi-architecture builds**
  - [ ] ath79/generic (current)
  - [ ] ramips/mt7621
  - [ ] x86/64
  - [ ] mediatek/filogic
- [ ] **Pre-built firmware images**
  - Integration with nodewatcher firmware generator
  - Popular device profiles (TP-Link, Ubiquiti, etc.)

### Phase 2: Enable All Modules (Priority: HIGH)

- [x] Core modules working (general, resources, interfaces, etc.)
- [ ] **Enable wireless module**
  - [ ] Add libiwinfo to Dockerfile dependencies
  - [ ] Test wireless scanning functionality
  - [ ] Document wireless module usage
- [ ] **Enable http_push module**
  - [ ] Add libcurl to Dockerfile dependencies
  - [ ] Test HTTP push to nodewatcher server
  - [ ] Configure push interval and endpoints

### Phase 3: Better User Experience (Priority: MEDIUM)

- [ ] **LuCI Application**
  - [ ] Create luci-app-nodewatcher package
  - [ ] Configuration UI (server URL, push interval)
  - [ ] Status display (connection status, last push)
  - [ ] Module enable/disable toggles
- [ ] **Auto-discovery**
  - [ ] mDNS/DNS-SD for finding nodewatcher server
  - [ ] Fallback to manual configuration
- [ ] **Default configuration**
  - [ ] Sensible defaults out of the box
  - [ ] First-run wizard (optional)

### Phase 4: Documentation (Priority: MEDIUM)

- [x] Build documentation (docs/BUILD.md)
- [x] Roadmap (docs/ROADMAP.md)
- [ ] **Quick Start Guide**
  - [ ] Installation steps
  - [ ] Basic configuration
  - [ ] Verification steps
- [ ] **User Guide**
  - [ ] All configuration options
  - [ ] Module descriptions
  - [ ] Troubleshooting
- [ ] **Developer Guide**
  - [ ] Architecture overview
  - [ ] Creating new modules
  - [ ] API reference
- [ ] **API Documentation**
  - [ ] JSON output format
  - [ ] ubus interface

### Phase 5: Quality & Testing (Priority: MEDIUM)

- [ ] **Automated Testing**
  - [ ] Unit tests for modules
  - [ ] Integration tests
  - [ ] CI test runner
- [ ] **Code Quality**
  - [ ] Static analysis (cppcheck, clang-tidy)
  - [ ] Memory leak detection (valgrind)
  - [ ] Code coverage reports
- [ ] **Reliability**
  - [ ] Crash recovery
  - [ ] Watchdog integration
  - [ ] Logging improvements

---

## How to Contribute a Feature

### Step 1: Create an Issue

1. Go to [GitHub Issues](https://github.com/valentt/nodewatcher-agent/issues)
2. Click "New Issue"
3. Use this template:

```markdown
## Feature Description
[Clear description of the feature]

## Use Case
[Why is this feature needed?]

## Proposed Solution
[How should it be implemented?]

## Checklist
- [ ] Design/planning
- [ ] Implementation
- [ ] Testing
- [ ] Documentation
- [ ] Code review
```

### Step 2: Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### Step 3: Implement

1. Write the code
2. Add tests if applicable
3. Update documentation
4. Test locally with Docker build

### Step 4: Create Pull Request

1. Push your branch
2. Create PR referencing the issue: `Fixes #123`
3. Wait for CI to pass
4. Request review

### Step 5: Merge & Close

1. After approval, merge PR
2. Issue auto-closes (if using `Fixes #123`)
3. Delete feature branch

---

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- MAJOR: Breaking changes
- MINOR: New features (backwards compatible)
- PATCH: Bug fixes

### Creating a Release

1. Update version in `CMakeLists.txt` and `openwrt/Makefile`
2. Update CHANGELOG.md
3. Create and push tag:
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
4. GitHub Actions will:
   - Build packages
   - Create GitHub Release
   - Attach .ipk artifacts

---

## Current Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Deployment | In Progress | 60% |
| Phase 2: All Modules | Not Started | 0% |
| Phase 3: User Experience | Not Started | 0% |
| Phase 4: Documentation | In Progress | 30% |
| Phase 5: Quality | Not Started | 0% |

**Next Priority:** GitHub Releases with auto-attached .ipk packages

---

## Quick Links

- [GitHub Repository](https://github.com/valentt/nodewatcher-agent)
- [Issues](https://github.com/valentt/nodewatcher-agent/issues)
- [Pull Requests](https://github.com/valentt/nodewatcher-agent/pulls)
- [Actions (CI)](https://github.com/valentt/nodewatcher-agent/actions)
- [Build Documentation](./BUILD.md)
