import frappe


MOBILE_ROLES = [
    "Developer",
    "Company Administrator",
    "Director",
    "Sales Admin",
    "Sales Manager",
    "Sales User",
    "Collection Admin",
    "Collection Manager",
    "Collection User",
    "Purchase Admin",
    "Purchase Manager",
    "Purchase User",
    "Buying Manager",
    "Buying User",
    "Warehouse Admin",
    "Warehouse Manager",
    "Warehouse User",
    "Quality Control Admin",
    "Quality Control Manager",
    "Quality Control User",
    "Logistics Admin",
    "Logistics Manager",
    "Logistics User",
    "Driver",
    "Finance Admin",
    "Finance Manager",
    "Finance User",
    "Accounting Admin",
    "Accounting Manager",
    "Accounting User",
    "Plantation Admin",
    "Plantation Manager",
    "Plantation Supervisor",
]

DEFAULT_ROLE_MODULES = {
    "Administrator": ["dashboard", "sales", "purchase", "stock", "warehouse", "logistics", "approvals"],
    "System Manager": ["dashboard", "sales", "purchase", "stock", "warehouse", "logistics", "approvals"],
    "Sales Admin": ["dashboard", "sales", "collection", "approvals"],
    "Sales Manager": ["dashboard", "sales", "collection", "approvals"],
    "Sales User": ["dashboard", "sales"],
    "Sales": ["dashboard", "sales"],
    "Collection Admin": ["dashboard", "collection", "approvals"],
    "Collection Manager": ["dashboard", "collection", "approvals"],
    "Collection User": ["dashboard", "collection"],
    "Purchase Admin": ["dashboard", "purchase", "approvals"],
    "Purchase Manager": ["dashboard", "purchase", "approvals"],
    "Purchase": ["dashboard", "purchase"],
    "Purchase User": ["dashboard", "purchase"],
    "Buying Manager": ["dashboard", "purchase", "approvals"],
    "Buying User": ["dashboard", "purchase"],
    "Warehouse Admin": ["dashboard", "stock", "warehouse", "approvals"],
    "Warehouse Manager": ["dashboard", "stock", "warehouse", "approvals"],
    "Warehouse User": ["dashboard", "stock", "warehouse"],
    "Stock Manager": ["dashboard", "stock", "warehouse"],
    "Stock User": ["dashboard", "stock", "warehouse"],
    "Warehouse": ["dashboard", "stock", "warehouse"],
    "Quality Control Admin": ["dashboard", "stock", "warehouse", "quality_control", "approvals"],
    "Quality Control Manager": ["dashboard", "stock", "warehouse", "quality_control", "approvals"],
    "Quality Control User": ["dashboard", "stock", "warehouse", "quality_control"],
    "Quality Control": ["dashboard", "stock", "warehouse", "quality_control"],
    "Logistics Admin": ["dashboard", "logistics", "approvals"],
    "Logistics Manager": ["dashboard", "logistics", "approvals"],
    "Logistics User": ["dashboard", "logistics"],
    "Logistics": ["dashboard", "logistics"],
    "Driver": ["dashboard", "logistics"],
    "Finance Admin": ["dashboard", "finance", "approvals"],
    "Finance Manager": ["dashboard", "finance", "approvals"],
    "Finance User": ["dashboard", "finance"],
    "Accounting Admin": ["dashboard", "accounting", "approvals"],
    "Accounting Manager": ["dashboard", "accounting", "approvals"],
    "Accounting User": ["dashboard", "accounting"],
    "Plantation Admin": ["dashboard", "plantation", "approvals"],
    "Plantation Manager": ["dashboard", "plantation", "approvals"],
    "Plantation Supervisor": ["dashboard", "plantation"],
    "Delivery User": ["dashboard", "logistics"],
}

WORKSPACE_SHORTCUTS = [
    {
        "label": "Mobile Settings",
        "type": "DocType",
        "link_to": "TMSX Mobile Settings",
        "color": "Green",
    },
    {
        "label": "Role Module Mapping",
        "type": "DocType",
        "link_to": "TMSX Mobile Role Module",
        "color": "Blue",
    },
    {"label": "Users", "type": "DocType", "link_to": "User", "color": "Grey"},
    {"label": "Roles", "type": "DocType", "link_to": "Role", "color": "Grey"},
    {
        "label": "Companies",
        "type": "DocType",
        "link_to": "Company",
        "color": "Grey",
    },
    {
        "label": "Warehouses",
        "type": "DocType",
        "link_to": "Warehouse",
        "color": "Grey",
    },
]

WORKSPACE_LINK_GROUPS = [
    {
        "label": "Mobile Configuration",
        "icon": "setting-gear",
        "links": [
            ("TMSX Mobile Settings", "DocType", "TMSX Mobile Settings"),
            ("Role Module Mapping", "DocType", "TMSX Mobile Role Module"),
            ("User", "DocType", "User"),
            ("Role", "DocType", "Role"),
            ("Role Profile", "DocType", "Role Profile"),
            ("Workflow", "DocType", "Workflow"),
            ("Workflow Action", "DocType", "Workflow Action"),
        ],
    },
    {
        "label": "Site Scope & Master Data",
        "icon": "organization",
        "links": [
            ("Company", "DocType", "Company"),
            ("Warehouse", "DocType", "Warehouse"),
            ("Item", "DocType", "Item"),
            ("Item Group", "DocType", "Item Group"),
            ("Customer", "DocType", "Customer"),
            ("Customer Group", "DocType", "Customer Group"),
            ("Supplier", "DocType", "Supplier"),
            ("Supplier Group", "DocType", "Supplier Group"),
            ("Employee", "DocType", "Employee"),
        ],
    },
    {
        "label": "Sales Mobile",
        "icon": "sales",
        "links": [
            ("Sales Visit", "DocType", "Sales Visit"),
            ("Sales Tracking Point", "DocType", "Sales Tracking Point"),
            ("Sales Order", "DocType", "Sales Order"),
            ("Sales Invoice", "DocType", "Sales Invoice"),
            ("Delivery Note", "DocType", "Delivery Note"),
            ("Payment Entry", "DocType", "Payment Entry"),
            ("Sales Analytics", "Report", "Sales Analytics"),
            ("Item-wise Sales Register", "Report", "Item-wise Sales Register"),
            ("Sales Order Analysis", "Report", "Sales Order Analysis"),
            ("Accounts Receivable", "Report", "Accounts Receivable"),
        ],
    },
    {
        "label": "Purchase Mobile",
        "icon": "buying",
        "links": [
            ("Material Request", "DocType", "Material Request"),
            ("Purchase Order", "DocType", "Purchase Order"),
            ("Purchase Receipt", "DocType", "Purchase Receipt"),
            ("Purchase Invoice", "DocType", "Purchase Invoice"),
            ("Supplier Quotation", "DocType", "Supplier Quotation"),
            ("Purchase Analytics", "Report", "Purchase Analytics"),
            ("Purchase Order Analysis", "Report", "Purchase Order Analysis"),
            ("Supplier Quotation Comparison", "Report", "Supplier Quotation Comparison"),
            ("Accounts Payable", "Report", "Accounts Payable"),
        ],
    },
    {
        "label": "Warehouse & Stock Mobile",
        "icon": "stock",
        "links": [
            ("Stock Entry", "DocType", "Stock Entry"),
            ("Stock Reconciliation", "DocType", "Stock Reconciliation"),
            ("Bin", "DocType", "Bin"),
            ("Batch", "DocType", "Batch"),
            ("Serial No", "DocType", "Serial No"),
            ("Stock Balance", "Report", "Stock Balance"),
            ("Stock Ledger", "Report", "Stock Ledger"),
            ("Stock Analytics", "Report", "Stock Analytics"),
            ("Item Shortage Report", "Report", "Item Shortage Report"),
        ],
    },
    {
        "label": "Logistics & QC Mobile",
        "icon": "truck",
        "links": [
            ("Delivery Activity Log", "DocType", "Delivery Activity Log"),
            ("Delivery Tracking Point", "DocType", "Delivery Tracking Point"),
            ("Delivery Trip", "DocType", "Delivery Trip"),
            ("Vehicle", "DocType", "Vehicle"),
            ("Driver", "DocType", "Driver"),
            ("Quality Inspection", "DocType", "Quality Inspection"),
            ("Quality Inspection Template", "DocType", "Quality Inspection Template"),
            ("Quality Goal", "DocType", "Quality Goal"),
            ("Quality Procedure", "DocType", "Quality Procedure"),
        ],
    },
    {
        "label": "Finance & Accounting Reports",
        "icon": "accounting",
        "links": [
            ("General Ledger", "Report", "General Ledger"),
            ("Trial Balance", "Report", "Trial Balance"),
            ("Profit and Loss Statement", "Report", "Profit and Loss Statement"),
            ("Balance Sheet", "Report", "Balance Sheet"),
            ("Cash Flow", "Report", "Cash Flow"),
            ("Payment Ledger", "Report", "Payment Ledger"),
        ],
    },
]


def after_install():
    setup_mobile_roles()
    setup_mobile_permissions()
    setup_mobile_settings()
    setup_mobile_workspace()


def setup_mobile_roles():
    if not frappe.db.exists("DocType", "Role"):
        return

    for role in MOBILE_ROLES:
        if frappe.db.exists("Role", role):
            continue
        doc = frappe.new_doc("Role")
        doc.role_name = role
        if doc.meta.has_field("desk_access"):
            doc.desk_access = 1
        if doc.meta.has_field("is_custom"):
            doc.is_custom = 1
        doc.insert(ignore_permissions=True)
    frappe.db.commit()


MOBILE_ROLE_DOCTYPE_PERMISSIONS = {
    "Sales User": {
        "Customer": {"read": 1, "select": 1},
        "Customer Group": {"read": 1, "select": 1},
        "Territory": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Item Group": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Price List": {"read": 1, "select": 1},
        "Item Price": {"read": 1, "select": 1},
        "Sales Order": {"read": 1, "select": 1, "create": 1, "write": 1},
        "Sales Order Item": {"read": 1, "select": 1},
        "Delivery Note": {"read": 1, "select": 1},
        "Delivery Note Item": {"read": 1, "select": 1},
        "Sales Invoice": {"read": 1, "select": 1},
        "Sales Invoice Item": {"read": 1, "select": 1},
        "Payment Entry": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
    "Sales Manager": {
        "Customer": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Sales Order": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1},
        "Delivery Note": {"read": 1, "select": 1},
        "Sales Invoice": {"read": 1, "select": 1},
        "Payment Entry": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
    "Sales Admin": {
        "Customer": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Sales Order": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1, "cancel": 1},
        "Delivery Note": {"read": 1, "select": 1},
        "Sales Invoice": {"read": 1, "select": 1},
        "Payment Entry": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
    "Purchase User": {
        "Supplier": {"read": 1, "select": 1},
        "Supplier Group": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Item Group": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Price List": {"read": 1, "select": 1},
        "Item Price": {"read": 1, "select": 1},
        "Material Request": {"read": 1, "select": 1, "create": 1, "write": 1},
        "Material Request Item": {"read": 1, "select": 1},
        "Purchase Order": {"read": 1, "select": 1, "create": 1, "write": 1},
        "Purchase Order Item": {"read": 1, "select": 1},
        "Purchase Receipt": {"read": 1, "select": 1, "create": 1, "write": 1},
        "Purchase Receipt Item": {"read": 1, "select": 1},
        "Purchase Invoice": {"read": 1, "select": 1, "create": 1, "write": 1},
        "Purchase Invoice Item": {"read": 1, "select": 1},
        "Supplier Quotation": {"read": 1, "select": 1},
        "Quality Inspection": {"read": 1, "select": 1, "create": 1, "write": 1},
        "File": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
    "Purchase Manager": {
        "Supplier": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Material Request": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1},
        "Purchase Order": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1},
        "Purchase Receipt": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1},
        "Purchase Invoice": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1},
        "Supplier Quotation": {"read": 1, "select": 1},
        "Quality Inspection": {"read": 1, "select": 1, "create": 1, "write": 1},
        "File": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
    "Purchase Admin": {
        "Supplier": {"read": 1, "select": 1},
        "Item": {"read": 1, "select": 1},
        "Warehouse": {"read": 1, "select": 1},
        "Material Request": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1, "cancel": 1},
        "Purchase Order": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1, "cancel": 1},
        "Purchase Receipt": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1, "cancel": 1},
        "Purchase Invoice": {"read": 1, "select": 1, "create": 1, "write": 1, "submit": 1, "cancel": 1},
        "Supplier Quotation": {"read": 1, "select": 1},
        "Quality Inspection": {"read": 1, "select": 1, "create": 1, "write": 1},
        "File": {"read": 1, "select": 1, "create": 1, "write": 1},
    },
}

MOBILE_REPORT_ROLES = {
    "Sales Analytics": ["Sales User", "Sales Manager", "Sales Admin"],
    "Sales Order Analysis": ["Sales User", "Sales Manager", "Sales Admin"],
    "Item-wise Sales Register": ["Sales User", "Sales Manager", "Sales Admin"],
    "Accounts Receivable": ["Sales Manager", "Sales Admin", "Collection User", "Collection Manager", "Collection Admin"],
    "Purchase Analytics": ["Purchase User", "Purchase Manager", "Purchase Admin", "Buying User", "Buying Manager"],
    "Purchase Order Analysis": ["Purchase User", "Purchase Manager", "Purchase Admin", "Buying User", "Buying Manager"],
    "Supplier Quotation Comparison": ["Purchase User", "Purchase Manager", "Purchase Admin", "Buying User", "Buying Manager"],
    "Accounts Payable": ["Purchase Manager", "Purchase Admin", "Finance User", "Finance Manager", "Finance Admin"],
}


def setup_mobile_permissions():
    if not frappe.db.exists("DocType", "Custom DocPerm"):
        return

    for role, doctypes in MOBILE_ROLE_DOCTYPE_PERMISSIONS.items():
        if not frappe.db.exists("Role", role):
            continue
        for doctype, permissions in doctypes.items():
            _ensure_custom_docperm(doctype, role, permissions)

    for report_name, roles in MOBILE_REPORT_ROLES.items():
        _ensure_report_roles(report_name, roles)

    frappe.clear_cache()
    frappe.db.commit()


def _ensure_custom_docperm(doctype, role, permissions):
    if not frappe.db.exists("DocType", doctype):
        return

    filters = {"parent": doctype, "role": role, "permlevel": 0}
    name = frappe.db.exists("Custom DocPerm", filters)
    doc = frappe.get_doc("Custom DocPerm", name) if name else frappe.new_doc("Custom DocPerm")
    doc.parent = doctype
    doc.parenttype = "DocType"
    doc.parentfield = "permissions"
    doc.role = role
    doc.permlevel = 0

    for field in (
        "read",
        "select",
        "create",
        "write",
        "submit",
        "cancel",
        "amend",
        "delete",
        "report",
        "export",
        "print",
        "email",
        "share",
    ):
        if doc.meta.has_field(field):
            doc.set(field, int(permissions.get(field, 0)))

    if name:
        doc.save(ignore_permissions=True)
    else:
        doc.insert(ignore_permissions=True)


def _ensure_report_roles(report_name, roles):
    if not frappe.db.exists("Report", report_name):
        return
    report = frappe.get_doc("Report", report_name)
    if not report.meta.has_field("roles"):
        return

    existing = {
        row.role
        for row in frappe.get_all(
            "Has Role",
            filters={
                "parent": report_name,
                "parenttype": "Report",
                "parentfield": "roles",
            },
            fields=["role"],
        )
    }
    for role in roles:
        if not frappe.db.exists("Role", role) or role in existing:
            continue
        doc = frappe.new_doc("Has Role")
        doc.parent = report_name
        doc.parenttype = "Report"
        doc.parentfield = "roles"
        doc.role = role
        doc.insert(ignore_permissions=True)
        existing.add(role)


def setup_mobile_settings():
    if not frappe.db.exists("DocType", "TMSX Mobile Settings"):
        return

    settings = frappe.get_single("TMSX Mobile Settings")
    settings.enabled = 1
    settings.default_modules = frappe.as_json(["dashboard"])
    settings.use_employee_company_scope = 1
    settings.allow_all_companies_for_system_manager = 1

    existing_rows = {row.role: row for row in settings.role_modules or []}
    for role, modules in DEFAULT_ROLE_MODULES.items():
        if not frappe.db.exists("Role", role):
            continue
        if role in existing_rows:
            existing_rows[role].modules = frappe.as_json(modules)
            continue
        settings.append(
            "role_modules",
            {
                "role": role,
                "modules": frappe.as_json(modules),
            },
        )

    settings.save(ignore_permissions=True)
    frappe.db.commit()


def setup_mobile_workspace():
    if not frappe.db.exists("DocType", "Workspace"):
        return

    workspace, is_new = _get_or_create_workspace()
    workspace.title = "TMSX Mobile"
    workspace.label = "TMSX Mobile"
    workspace.module = "TMSX Mobile"
    workspace.parent_page = ""
    workspace.public = 1
    workspace.is_hidden = 0
    workspace.icon = "device-mobile"
    workspace.indicator_color = "green"
    workspace.sequence_id = 999

    _reset_child_table(workspace, "shortcuts")
    _reset_child_table(workspace, "links")

    shortcut_labels = []
    for shortcut in WORKSPACE_SHORTCUTS:
        if _append_shortcut(workspace, shortcut):
            shortcut_labels.append(shortcut["label"])

    card_labels = []
    for group in WORKSPACE_LINK_GROUPS:
        if _append_link_group(workspace, group):
            card_labels.append(group["label"])

    workspace.content = frappe.as_json(
        _workspace_content(shortcut_labels, card_labels)
    )

    if is_new:
        workspace.insert(ignore_permissions=True)
    else:
        workspace.save(ignore_permissions=True)
    frappe.db.commit()


def _get_or_create_workspace():
    name = frappe.db.exists("Workspace", "TMSX Mobile")
    if name:
        return frappe.get_doc("Workspace", name), False
    workspace = frappe.new_doc("Workspace")
    workspace.name = "TMSX Mobile"
    workspace.label = "TMSX Mobile"
    return workspace, True


def _reset_child_table(doc, fieldname):
    if doc.meta.has_field(fieldname):
        doc.set(fieldname, [])


def _append_if_table_exists(doc, fieldname, row):
    if doc.meta.has_field(fieldname):
        doc.append(fieldname, row)


def _append_shortcut(workspace, shortcut):
    if not workspace.meta.has_field("shortcuts"):
        return False
    if not _link_target_exists(shortcut["type"], shortcut["link_to"]):
        return False
    workspace.append(
        "shortcuts",
        {
            "label": shortcut["label"],
            "type": shortcut["type"],
            "link_to": shortcut["link_to"],
            "color": shortcut.get("color", "Grey"),
            "doc_view": shortcut.get("doc_view", "List"),
            "stats_filter": shortcut.get("stats_filter", ""),
            "format": shortcut.get("format", ""),
        },
    )
    return True


def _append_link_group(workspace, group):
    if not workspace.meta.has_field("links"):
        return False

    valid_links = [
        link
        for link in group["links"]
        if _link_target_exists(link[1], link[2])
    ]
    if not valid_links:
        return False

    workspace.append(
        "links",
        {
            "type": "Card Break",
            "label": group["label"],
            "icon": group.get("icon", ""),
            "hidden": 0,
            "link_count": len(valid_links),
        },
    )
    for label, link_type, link_to in valid_links:
        workspace.append(
            "links",
            {
                "type": "Link",
                "label": label,
                "link_type": link_type,
                "link_to": link_to,
                "hidden": 0,
                "onboard": 0,
                "is_query_report": 1 if link_type == "Report" else 0,
            },
        )
    return True


def _link_target_exists(link_type, link_to):
    if link_type == "DocType":
        return frappe.db.exists("DocType", link_to)
    if link_type == "Report":
        return frappe.db.exists("Report", link_to)
    if link_type == "Page":
        return frappe.db.exists("Page", link_to)
    return True


def _workspace_content(shortcut_labels, card_labels):
    content = [
        {
            "id": "tmsx_mobile_header",
            "type": "header",
            "data": {"text": "TMSX Mobile", "col": 12},
        },
        {
            "id": "tmsx_mobile_spacer_1",
            "type": "spacer",
            "data": {"col": 12},
        },
        {
            "id": "tmsx_mobile_shortcut_header",
            "type": "header",
            "data": {"text": "Quick Setup", "col": 12},
        },
    ]

    for index, label in enumerate(shortcut_labels):
        content.append(
            {
                "id": f"tmsx_mobile_shortcut_{index}",
                "type": "shortcut",
                "data": {"shortcut_name": label, "col": 3},
            }
        )

    content.extend(
        [
            {
                "id": "tmsx_mobile_spacer_2",
                "type": "spacer",
                "data": {"col": 12},
            },
            {
                "id": "tmsx_mobile_card_header",
                "type": "header",
                "data": {"text": "Mobile ERP Workspace", "col": 12},
            },
        ]
    )

    for index, label in enumerate(card_labels):
        content.append(
            {
                "id": f"tmsx_mobile_card_{index}",
                "type": "card",
                "data": {"card_name": label, "col": 4},
            }
        )
    return content
