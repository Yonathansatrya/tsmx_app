import frappe


DEFAULT_ROLE_MODULES = {
    "Administrator": ["dashboard", "sales", "purchase", "stock", "warehouse", "logistics", "approvals"],
    "System Manager": ["dashboard", "sales", "purchase", "stock", "warehouse", "logistics", "approvals"],
    "Sales Manager": ["dashboard", "sales", "approvals"],
    "Sales User": ["dashboard", "sales"],
    "Sales": ["dashboard", "sales"],
    "Purchase Manager": ["dashboard", "purchase", "approvals"],
    "Purchase User": ["dashboard", "purchase"],
    "Buying Manager": ["dashboard", "purchase", "approvals"],
    "Buying User": ["dashboard", "purchase"],
    "Stock Manager": ["dashboard", "stock", "warehouse"],
    "Stock User": ["dashboard", "stock", "warehouse"],
    "Warehouse": ["dashboard", "stock", "warehouse"],
    "Logistics": ["dashboard", "logistics"],
    "Delivery User": ["dashboard", "logistics"],
}


def after_install():
    setup_mobile_settings()


def setup_mobile_settings():
    if not frappe.db.exists("DocType", "TMSX Mobile Settings"):
        return

    settings = frappe.get_single("TMSX Mobile Settings")
    settings.enabled = 1
    settings.default_modules = frappe.as_json(["dashboard"])
    settings.use_employee_company_scope = 1
    settings.allow_all_companies_for_system_manager = 1

    existing_roles = {row.role for row in settings.role_modules or []}
    for role, modules in DEFAULT_ROLE_MODULES.items():
        if role in existing_roles:
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
