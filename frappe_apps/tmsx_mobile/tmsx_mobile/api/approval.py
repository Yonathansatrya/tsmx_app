import frappe
from frappe import _
from frappe.utils import now


@frappe.whitelist()
def add_sales_order_approver(
    sales_order, approver, approval_type="Additional", reason=None, note=None
):
    sales_order = (sales_order or "").strip()
    approver = (approver or "").strip()
    approval_type = (approval_type or "Additional").strip() or "Additional"
    reason = (reason or note or "").strip()

    if not sales_order:
        frappe.throw(_("Sales Order wajib diisi."))
    if not approver:
        frappe.throw(_("Approver wajib dipilih."))
    if not reason:
        frappe.throw(_("Reason / Note wajib diisi untuk Additional Approval."))
    if not frappe.db.exists("Sales Order", sales_order):
        frappe.throw(_("Sales Order tidak ditemukan."))
    if not frappe.db.exists("User", approver):
        frappe.throw(_("User approver tidak ditemukan."))

    user_enabled = frappe.db.get_value("User", approver, "enabled")
    if not user_enabled:
        frappe.throw(_("User approver tidak aktif."))

    doc = frappe.get_doc("Sales Order", sales_order)
    doc.check_permission("read")
    doc.check_permission("write")

    workflow_state = (doc.get("workflow_state") or "").strip()
    if workflow_state.lower() != "pending for lead":
        frappe.throw(
            _("Additional approver hanya bisa ditambahkan saat workflow Pending for Lead.")
        )

    meta = frappe.get_meta("Sales Order")
    table_field = meta.get_field("approvers")
    if not table_field or table_field.fieldtype != "Table":
        frappe.throw(_("Field approvers belum tersedia pada Sales Order."))
    child_meta = frappe.get_meta(table_field.options)

    for row in doc.get("approvers") or []:
        if (row.get("approver") or "").strip() == approver:
            _set_child_db_value_if_exists(row, "reason", reason)
            _set_child_db_value_if_exists(row, "note", reason)
            _set_child_db_value_if_exists(row, "remarks", reason)
            _set_child_db_value_if_exists(row, "remark", reason)
            frappe.db.commit()
            return {
                "name": doc.name,
                "workflow_state": workflow_state,
                "approver": approver,
                "already_exists": True,
            }

    approver_payload = {
        "approver": approver,
        "approval_type": approval_type,
        "status": "Pending",
        "requested_by": frappe.session.user,
    }
    for fieldname in ("reason", "note", "remarks", "remark"):
        if child_meta.get_field(fieldname):
            approver_payload[fieldname] = reason
    if child_meta.get_field("requested_at"):
        approver_payload["requested_at"] = now()

    doc.append("approvers", approver_payload)
    doc.add_comment(
        "Comment",
        _(
            "Additional approver {0} ditambahkan oleh {1}.<br>Reason: {2}"
        ).format(frappe.bold(approver), frappe.bold(frappe.session.user), reason),
    )
    doc.save()

    _assign_additional_approver(doc.name, approver)
    frappe.db.commit()

    return {
        "name": doc.name,
        "workflow_state": workflow_state,
        "approver": approver,
        "already_exists": False,
    }


@frappe.whitelist()
def decide_sales_order_additional_approval(sales_order, decision, reason=None):
    sales_order = (sales_order or "").strip()
    decision = (decision or "").strip().lower()
    reason = (reason or "").strip()
    current_user = frappe.session.user

    if not sales_order:
        frappe.throw(_("Sales Order wajib diisi."))
    if decision not in ("approve", "approved", "reject", "rejected"):
        frappe.throw(_("Decision harus Approve atau Reject."))
    if decision in ("reject", "rejected") and not reason:
        frappe.throw(_("Alasan reject wajib diisi."))
    if not frappe.db.exists("Sales Order", sales_order):
        frappe.throw(_("Sales Order tidak ditemukan."))

    doc = frappe.get_doc("Sales Order", sales_order)
    doc.check_permission("read")

    meta = frappe.get_meta("Sales Order")
    table_field = meta.get_field("approvers")
    if not table_field or table_field.fieldtype != "Table":
        frappe.throw(_("Field approvers belum tersedia pada Sales Order."))

    target_row = None
    for row in doc.get("approvers") or []:
        approver = (row.get("approver") or "").strip()
        approval_type = (row.get("approval_type") or "Additional").strip().lower()
        status = (row.get("status") or "Pending").strip().lower()
        if (
            approver == current_user
            and approval_type == "additional"
            and status == "pending"
        ):
            target_row = row
            break

    if target_row is None:
        frappe.throw(_("Tidak ada additional approval pending untuk user ini."))

    approved = decision in ("approve", "approved")
    status = "Approved" if approved else "Rejected"
    decision_time = now()
    _set_child_db_value_if_exists(target_row, "status", status)
    _set_child_db_value_if_exists(
        target_row, "approved_by", current_user if approved else ""
    )
    _set_child_db_value_if_exists(
        target_row, "approved_on", decision_time if approved else ""
    )
    _set_child_db_value_if_exists(
        target_row, "rejected_by", current_user if not approved else ""
    )
    _set_child_db_value_if_exists(
        target_row, "rejected_on", decision_time if not approved else ""
    )
    _set_child_db_value_if_exists(target_row, "action_by", current_user)
    _set_child_db_value_if_exists(target_row, "responded_by", current_user)
    _set_child_db_value_if_exists(target_row, "decision_on", decision_time)
    _set_child_db_value_if_exists(target_row, "remarks", reason)
    _set_child_db_value_if_exists(target_row, "remark", reason)
    _set_child_db_value_if_exists(target_row, "reason", reason)

    comment = _("Additional approval {0} oleh {1}.").format(
        frappe.bold(status), frappe.bold(current_user)
    )
    if reason:
        comment = "{0}<br>{1}: {2}".format(comment, _("Alasan"), frappe.bold(reason))
    doc.add_comment("Comment", comment)

    _close_additional_approval_assignment(doc.name, current_user)
    frappe.db.commit()

    return {
        "name": doc.name,
        "approver": current_user,
        "status": status,
    }


def _set_child_value_if_exists(row, fieldname, value):
    try:
        if row.meta.get_field(fieldname):
            row.set(fieldname, value)
    except Exception:
        pass


def _set_child_db_value_if_exists(row, fieldname, value):
    try:
        if row.meta.get_field(fieldname):
            frappe.db.set_value(
                row.doctype,
                row.name,
                fieldname,
                value,
                update_modified=True,
            )
    except Exception:
        pass


def _assign_additional_approver(sales_order, approver):
    try:
        from frappe.desk.form.assign_to import add as add_assignment

        add_assignment(
            {
                "assign_to": [approver],
                "doctype": "Sales Order",
                "name": sales_order,
                "description": _("Additional approval requested"),
            }
        )
    except Exception:
        frappe.log_error(
            frappe.get_traceback(),
            "TMSX Mobile additional approver assignment failed",
        )


def _close_additional_approval_assignment(sales_order, approver):
    try:
        todos = frappe.get_all(
            "ToDo",
            filters={
                "reference_type": "Sales Order",
                "reference_name": sales_order,
                "allocated_to": approver,
                "status": "Open",
            },
            fields=["name", "description"],
        )
        for todo in todos:
            description = (todo.get("description") or "").strip().lower()
            if "additional approval" not in description:
                continue
            frappe.db.set_value(
                "ToDo",
                todo.name,
                "status",
                "Closed",
                update_modified=True,
            )
    except Exception:
        frappe.log_error(
            frappe.get_traceback(),
            "TMSX Mobile additional approver close assignment failed",
        )
