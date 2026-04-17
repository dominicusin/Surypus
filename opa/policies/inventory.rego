# ============================================================================
# Inventory Domain Policies
# ============================================================================
# Business rules for inventory management
# ============================================================================

package surypus.inventory

import future.keywords.if
import future.keywords.in

# ============================================================================
# INVENTORY CONSTRAINTS
# ============================================================================

# Max write-off percentage allowed
MAX_WRITEOFF_PCT := 0.10  # 10%

# Min stock level for critical items
MIN_CRITICAL_STOCK := 1

# ============================================================================
# FIFO VALIDATION
# ============================================================================

# Validate FIFO selection is correct
valid_fifo_selection if {
    lots := input.selected_lots
    total_selected := sum([lot.qty | some lot in lots])
    total_selected == input.qty_needed
    
    # Check FIFO order
    dates := [lot.lot_date | some lot in lots]
    is_sorted(dates)
}

# Check array is sorted (oldest first)
is_sorted(arr) if {
    count(arr) <= 1
}

is_sorted(arr) if {
    count(arr) > 1
    arr[0] <= arr[1]
    rest := array.slice(arr, 1, count(arr))
    is_sorted(rest)
}

# ============================================================================
# STOCK VALIDATION
# ============================================================================

# Validate stock adjustment
valid_adjustment if {
    adjustment := input.adjustment_qty
    current := input.current_qty
    
    # Cannot adjust to negative
    current + adjustment >= 0
    
    # Adjustment within reasonable bounds
    abs(adjustment) <= current * 2
}

# Validate write-off amount
valid_writeoff if {
    writeoff := input.writeoff_qty
    current := input.current_qty
    
    writeoff >= 0
    writeoff <= current * MAX_WRITEOFF_PCT
}

# Check if reorder needed
reorder_needed if {
    current := input.current_qty
    reorder_point := input.reorder_point
    
    current <= reorder_point
}

# ============================================================================
# BUSINESS RULES
# ============================================================================

# Cannot issue expired lots
cannot_issue_expired if {
    some lot in input.selected_lots
    lot.expiry_date < input.issue_date
}

# Cannot issue negative quantity
cannot_issue_negative if {
    input.qty_needed < 0
}

# Cannot issue more than available
cannot_overissue if {
    available := input.available_qty
    needed := input.qty_needed
    needed > available
}

# ============================================================================
# DECISIONS
# ============================================================================

# Allow stock issue
allow_issue if {
    not cannot_issue_expired
    not cannot_issue_negative
    not cannot_overissue
    valid_fifo_selection
}

# Allow stock adjustment
allow_adjust if {
    valid_adjustment
    input.user.has_permission("inventory", "adjust")
}

# Allow write-off
allow_writeoff if {
    valid_writeoff
    input.user.has_permission("inventory", "write")
    input.reason != ""
}

# ============================================================================
# COST VALIDATION
# ============================================================================

# Validate cost is within expected range
valid_cost if {
    cost := input.cost
    avg_cost := input.avg_cost
    
    cost > 0
    cost <= avg_cost * 2  # Max 2x average cost
    cost >= avg_cost * 0.5  # Min 0.5x average cost
}
