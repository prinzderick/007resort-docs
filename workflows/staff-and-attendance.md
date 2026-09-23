# Workflow: Staff shift, from clock-in to clock-out

```mermaid
sequenceDiagram
  actor St as Staff member
  participant Gate as Biometric terminal (Main Gate)
  participant API as 007resort-api
  actor Sup as Supervisor
  actor Dev as Terminal/tablet

  St->>Gate: Clock in (biometric)
  Gate->>API: POST /attendance/punches
  API->>API: attendance_punch -> derive attendance_day

  alt Shared attendant tablet
    St->>Dev: Sign in, checkout tablet (device -> staff -> shift -> facility)
    Dev->>API: POST /devices/{id}/checkout
  else Fixed POS
    St->>Dev: NFC + PIN
    Dev->>API: POST /auth/staff/login
  end

  St->>API: Perform permitted actions (order, payment, etc.)
  opt Sensitive action
    API->>API: create PENDING_APPROVAL + approval row
    Sup->>API: POST /approvals/{id}/decide
  end
  API->>API: audit_log row per sensitive/mutating action

  St->>Dev: End of shift — checkin tablet / sign out
  Dev->>API: POST /devices/{id}/checkin
  St->>Gate: Clock out (biometric)
  Gate->>API: POST /attendance/punches
```

See [06 Roles and permissions matrix](../architecture/06-roles-permissions.md) for authentication requirements per station type and the approval workflow, and [17 Security model](../architecture/17-security-model.md) for audit requirements.
