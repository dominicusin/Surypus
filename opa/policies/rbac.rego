# ============================================================================
# Surypus OPA Policies
# ============================================================================
# Role-Based Access Control with resource-level permissions
# ============================================================================

package surypus.rbac

import future.keywords.if
import future.keywords.in

# ============================================================================
# DATA STRUCTURES
# ============================================================================

# Default allow/deny
default allow := false

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Check if user has superuser access
is_superuser if {
    input.user.is_superuser == true
}

# Check if user has a specific role
has_role(role_code) if {
    some role in input.roles
    role.role_code == role_code
}

# Check if user has specific permission
has_permission(resource, action) if {
    some perm in input.permissions
    perm.resource == resource
    perm.action == action
}

# Check if user is tenant owner
is_tenant_owner if {
    input.user.user_id == data.tenant_owners[input.tenant_id]
}

# Check if resource belongs to user's tenant
belongs_to_tenant if {
    input.resource_data.tenant_id == input.tenant_id
}

# ============================================================================
# CORE AUTHORIZATION RULES
# ============================================================================

# Superusers can do anything
allow if {
    is_superuser
}

# Allow if user has explicit permission and belongs to tenant
allow if {
    has_permission(input.resource, input.action)
    belongs_to_tenant
}

# Tenant owners can manage their tenant
allow if {
    has_role("tenant_admin")
    input.tenant_id == input.resource_data.tenant_id
}

# ============================================================================
# RESOURCE-SPECIFIC RULES
# ============================================================================

# Inventory rules
allow if {
    input.resource == "inventory"
    input.action == "adjust"
    has_role("manager")
    input.resource_data.quantity_delta < 1000
}

# Large adjustments need admin approval
allow if {
    input.resource == "inventory"
    input.action == "adjust"
    has_permission("inventory", "approve")
}

# Bill posting rules
allow if {
    input.resource == "bill"
    input.action == "post"
    has_permission("bill", "post")
    input.resource_data.amount <= data.tenant_limits[input.tenant_id].max_bill_amount
}

# Bills over limit need approval
allow if {
    input.resource == "bill"
    input.action == "post"
    has_permission("bill", "approve")
}

# Salary rules - cannot approve own salary
allow if {
    input.resource == "salary"
    input.action == "approve"
    has_permission("salary", "approve")
    input.resource_data.employee_id != input.user.user_id
}

# ============================================================================
# DENY RULES (overrides allows)
# ============================================================================

# Deny if user is not active
deny if {
    input.user.is_active == false
}

# Deny if tenant is suspended
deny if {
    data.tenant_status[input.tenant_id] == "suspended"
}

# Deny salary operations outside business hours
deny if {
    input.resource == "salary"
    input.action == "pay"
    [hour, _] := time.clock(time.now_ns())
    hour < 9
}

deny if {
    input.resource == "salary"
    input.action == "pay"
    [hour, _] := time.clock(time.now_ns())
    hour >= 18
}

# Deny if user is trying to modify their own salary

# ============================================================================
# DECISION METADATA
# ============================================================================

reason = "superuser access" if { is_superuser }
reason = "has permission" if { 
    has_permission(input.resource, input.action)
    not is_superuser
}
reason = "tenant owner" if { is_tenant_owner }
reason = "role based access" if { 
    has_role("manager")
    not has_permission(input.resource, input.action)
}

deny_reason = "user not active" if { input.user.is_active == false }
deny_reason = "tenant suspended" if { data.tenant_status[input.tenant_id] == "suspended" }
deny_reason = "outside business hours" if {
    input.resource == "salary"
    [hour, _] := time.clock(time.now_ns())
    hour < 9
}
deny_reason = "outside business hours" if {
    input.resource == "salary"
    [hour, _] := time.clock(time.now_ns())
    hour >= 18
}

# ============================================================================
# AUDIT LOG
# ============================================================================

audit_log := {
    "user_id": input.user.user_id,
    "resource": input.resource,
    "action": input.action,
    "tenant_id": input.tenant_id,
    "decision": decision,
    "reason": reason,
    "timestamp": time.now_ns()
}

decision := "allow" if {
    allow
    not deny
}

decision := "deny" if {
    deny
}

decision := "deny" if {
    not allow
}
