# KingSecure Homelab - GPO Documentation

## Domain: kingsecure.bj

---

## GPO 1 — Account Lockout Policy
**Linked to:** kingsecure.bj (domain root)
**Scope:** All computers in domain

| Setting | Value | Path |
|---------|-------|------|
| Account lockout threshold | 3 attempts | Computer Config → Security Settings → Account Policies |
| Account lockout duration | 15 minutes | Same |
| Reset lockout counter after | 15 minutes | Same |

> ⚠️ Must be linked at domain root level — OU-level lockout policies are ignored by Windows.

---

## GPO 2 — WinRM Enablement
**Linked to:** kingsecure.bj (domain root)
**Scope:** All computers in domain

Enables Windows Remote Management for remote PowerShell and management.

| Setting | Value |
|---------|-------|
| Windows Remote Management (WinRM) service | Automatic |
| Allow remote server management | Enabled |

---

## GPO 3 — Control Panel Restriction (HR)
**Linked to:** OU=HR Department
**Scope:** HR users only

Uses **whitelist approach** (Show only specified items) — more maintainable than blacklisting.

| Setting | Value | Path |
|---------|-------|------|
| Show only specified Control Panel items | Enabled | User Config → Admin Templates → Control Panel |
| Allowed items | Display, Sound (example) | Same |

---

## GPO 4 — Desktop Wallpaper
**Linked to:** kingsecure.bj (domain root)
**Scope:** All users

| Setting | Value | Path |
|---------|-------|------|
| Desktop Wallpaper | \\WinServer25-01\Wallpapers\corp-wallpaper.jpg | User Config → Admin Templates → Desktop → Desktop |
| Wallpaper Style | Fill | Same |

---

## GPO 5 — AUP Login Banner
**Linked to:** kingsecure.bj (domain root)
**Scope:** All computers

| Setting | Value | Path |
|---------|-------|------|
| Interactive logon: Message title | KingSecure IT Policy | Computer Config → Security Settings → Local Policies |
| Interactive logon: Message text | Acceptable Use Policy text | Same |

---

## GPO 6 — Shared Drive Mapping
**Linked to:** kingsecure.bj (domain root)
**Scope:** All users (filtered by security group)

| Department | Drive Letter | Share Path |
|------------|-------------|-----------|
| IT | Z: | \\WinServer25-01\IT |
| HR | Y: | \\WinServer25-01\HR |
| Management | X: | \\WinServer25-01\Management |

Path: User Config → Preferences → Windows Settings → Drive Maps

---

## Known Issues

### Lock Screen GPO Not Rendering on Windows 10
**Symptom:** Registry shows policy applied but lock screen doesn't change visually.
**Cause:** Windows Spotlight overrides the lock screen image even when GPO is applied.
**Workaround:** Disable Windows Spotlight via GPO or manually.

**Registry verification:**
```
HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization
Value: LockScreenImage = \\WINSERVER25-01\Wallpaper\image.png
```
Policy IS applied — this is a Spotlight display override issue.
