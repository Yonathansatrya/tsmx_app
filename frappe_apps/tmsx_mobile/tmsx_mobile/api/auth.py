import frappe
from frappe.utils import cint

MOBILE_MODULES = [
    "dashboard",
    "executive",
    "sales",
    "collection",
    "purchase",
    "stock",
    "warehouse",
    "quality_control",
    "logistics",
    "approvals",
    "finance",
    "accounting",
    "plantation",
]

FULL_ACCESS_ROLES = {
    "administrator",
    "system manager",
    "developer",
    "company administrator",
    "director",
    "owner",
    "executive",
}

MENU_MAP = {
    "dashboard": {
        "module": "dashboard",
        "label": "Beranda",
        "icon": "dashboard",
        "order": 10,
    },
    "executive": {
        "module": "executive",
        "label": "Executive",
        "icon": "insights",
        "order": 15,
    },
    "sales": {
        "module": "sales",
        "label": "Sales",
        "icon": "point_of_sale",
        "order": 20,
    },
    "collection": {
        "module": "collection",
        "label": "Collection",
        "icon": "account_balance_wallet",
        "order": 25,
    },
    "approvals": {
        "module": "approvals",
        "label": "Todo",
        "icon": "checklist",
        "order": 30,
    },
    "purchase": {
        "module": "purchase",
        "label": "Buying",
        "icon": "shopping_bag",
        "order": 40,
    },
    "stock": {
        "module": "stock",
        "label": "Stock",
        "icon": "inventory",
        "order": 50,
    },
    "warehouse": {
        "module": "warehouse",
        "label": "Warehouse",
        "icon": "warehouse",
        "order": 60,
    },
    "quality_control": {
        "module": "quality_control",
        "label": "Quality Control",
        "icon": "fact_check",
        "order": 65,
    },
    "logistics": {
        "module": "logistics",
        "label": "Logistics",
        "icon": "route",
        "order": 70,
    },
    "finance": {
        "module": "finance",
        "label": "Finance",
        "icon": "payments",
        "order": 80,
    },
    "accounting": {
        "module": "accounting",
        "label": "Accounting",
        "icon": "calculate",
        "order": 85,
    },
    "plantation": {
        "module": "plantation",
        "label": "Plantation",
        "icon": "agriculture",
        "order": 90,
    },
}

ROLE_ALIASES = {
    "developer": "Developer",
    "system manager": "Administrator",
    "administrator": "Administrator",
    "company administrator": "Company Administrator",
    "director": "Director",
    "owner": "Director",
    "executive": "Director",
    "sales manager": "Sales Manager",
    "sales user": "Sales",
    "selling user": "Sales",
    "sales": "Sales",
    "collection user": "Collection",
    "collection manager": "Collection",
    "collection": "Collection",
    "accounts receivable": "Collection",
    "purchase manager": "Purchase Manager",
    "buying manager": "Purchase Manager",
    "purchase user": "Purchase",
    "buying user": "Purchase",
    "purchase": "Purchase",
    "quality control": "Quality Control",
    "quality manager": "Quality Control",
    "qc manager": "Quality Control",
    "qc user": "Quality Control",
    "warehouse manager": "Warehouse",
    "warehouse user": "Warehouse",
    "stock manager": "Warehouse",
    "stock user": "Warehouse",
    "warehouse": "Warehouse",
    "logistics manager": "Logistics",
    "delivery manager": "Logistics",
    "logistics": "Logistics",
    "delivery user": "Driver",
    "driver": "Driver",
    "finance manager": "Finance",
    "finance user": "Finance",
    "finance": "Finance",
    "accounts manager": "Accounting",
    "accountant": "Accounting",
    "accounting": "Accounting",
    "plantation supervisor": "Plantation Supervisor",
    "plantation manager": "Plantation Supervisor",
    "plantation": "Plantation Supervisor",
}


@frappe.whitelist()
def get_mobile_boot():
    """Return lightweight mobile session metadata for the logged-in user."""
    user = frappe.session.user
    if not user or user == "Guest":
        frappe.throw("Login required", frappe.AuthenticationError)

    user_doc = frappe.get_doc("User", user)
    roles = frappe.get_roles(user)
    settings = _mobile_settings()
    role_rule = _matching_role_rule(settings, roles)
    companies = _configured_scope(
        role_rule,
        "company_scope",
        fallback=lambda: _allowed_companies(user, user_doc, settings),
    )
    default_company = _default_company(user_doc, companies)
    warehouses = _configured_scope(
        role_rule,
        "warehouse_scope",
        fallback=lambda: _allowed_warehouses(default_company),
    )
    modules = _configured_modules(settings, role_rule, roles)

    return {
        "boot_version": 1,
        "app": {
            "name": "TMSX Hub",
            "tagline": "Mobile ERP",
        },
        "user": user,
        "full_name": user_doc.full_name,
        "role_profile_name": user_doc.role_profile_name,
        "role": _mobile_role_for_user(user_doc, roles),
        "roles": roles,
        "default_company": default_company,
        "companies": companies,
        "warehouses": warehouses,
        "modules": modules,
        "menus": _mobile_menus(modules),
        "permissions": {
            "default_company": default_company,
            "companies": companies,
            "warehouses": warehouses,
            "modules": modules,
        },
        "scope": {
            "company_field": "company",
            "warehouse_field": "warehouse",
            "default_company": default_company,
            "allowed_companies": companies,
            "allowed_warehouses": warehouses,
        },
}


def _mobile_menus(modules):
    return [
        MENU_MAP[module]
        for module in sorted(
            modules,
            key=lambda value: MENU_MAP.get(value, {}).get("order", 999),
        )
        if module in MENU_MAP
    ]


def _mobile_settings():
    try:
        if frappe.db.exists("DocType", "TMSX Mobile Settings"):
            return frappe.get_single("TMSX Mobile Settings")
    except Exception:
        return None
    return None


def _allowed_companies(user, user_doc, settings):
    role_names = {role.lower() for role in frappe.get_roles(user)}
    allow_all_for_system_manager = settings is None or cint(
        getattr(settings, "allow_all_companies_for_system_manager", 1)
    )
    if allow_all_for_system_manager and role_names & {
        "administrator",
        "system manager",
    }:
        return _all_companies()

    use_employee_scope = settings is None or cint(
        getattr(settings, "use_employee_company_scope", 1)
    )
    employee_company = _employee_company(user) if use_employee_scope else None
    if employee_company:
        return [employee_company]

    user_default_company = getattr(user_doc, "company", None)
    if user_default_company:
        return [user_default_company]

    return _all_companies()


def _all_companies():
    return frappe.get_all(
        "Company",
        filters={"is_group": 0},
        pluck="name",
        order_by="name asc",
    )


def _employee_company(user):
    employee = frappe.get_all(
        "Employee",
        filters={"user_id": user, "status": "Active"},
        fields=["company"],
        limit=1,
    )
    if not employee:
        return None
    return employee[0].company


def _default_company(user_doc, companies):
    user_default_company = getattr(user_doc, "company", None)
    if user_default_company:
        return user_default_company
    return companies[0] if companies else ""


def _mobile_role_for_user(user_doc, roles):
    role_profile = getattr(user_doc, "role_profile_name", None)
    if role_profile:
        return role_profile

    role_names = {role.lower() for role in roles}
    for alias, canonical in (
        ("developer", "Developer"),
        ("administrator", "Administrator"),
        ("system manager", "Administrator"),
        ("company administrator", "Company Administrator"),
        ("director", "Director"),
        ("owner", "Director"),
        ("executive", "Director"),
        ("sales manager", "Sales Manager"),
        ("sales user", "Sales"),
        ("selling user", "Sales"),
        ("sales", "Sales"),
        ("collection user", "Collection"),
        ("collection manager", "Collection"),
        ("collection", "Collection"),
        ("purchase manager", "Purchase Manager"),
        ("buying manager", "Purchase Manager"),
        ("purchase user", "Purchase"),
        ("buying user", "Purchase"),
        ("purchase", "Purchase"),
        ("quality control", "Quality Control"),
        ("quality manager", "Quality Control"),
        ("warehouse manager", "Warehouse"),
        ("warehouse user", "Warehouse"),
        ("stock manager", "Warehouse"),
        ("stock user", "Warehouse"),
        ("warehouse", "Warehouse"),
        ("logistics manager", "Logistics"),
        ("delivery manager", "Logistics"),
        ("logistics", "Logistics"),
        ("delivery user", "Driver"),
        ("driver", "Driver"),
        ("finance manager", "Finance"),
        ("finance user", "Finance"),
        ("finance", "Finance"),
        ("accounts manager", "Accounting"),
        ("accountant", "Accounting"),
        ("accounting", "Accounting"),
        ("plantation supervisor", "Plantation Supervisor"),
        ("plantation manager", "Plantation Supervisor"),
        ("plantation", "Plantation Supervisor"),
    ):
        if alias in role_names:
            return canonical
    return "Unassigned"


def _allowed_warehouses(default_company):
    filters = {"is_group": 0, "disabled": 0}
    if default_company:
        filters["company"] = default_company

    return frappe.get_all(
        "Warehouse",
        filters=filters,
        pluck="name",
        order_by="name asc",
    )


def _matching_role_rule(settings, roles):
    if not settings:
        return None
    role_names = {role.lower() for role in roles}
    for row in getattr(settings, "role_modules", []) or []:
        role = (row.role or "").strip().lower()
        if role and role in role_names:
            return row
    return None


def _configured_modules(settings, role_rule, roles):
    if role_rule:
        modules = _json_list(getattr(role_rule, "modules", None))
        if modules:
            return modules

    if settings:
        default_modules = _json_list(getattr(settings, "default_modules", None))
        if default_modules:
            role_modules = set(_mobile_modules_for_roles(roles))
            return sorted(set(default_modules) | role_modules)

    return _mobile_modules_for_roles(roles)


def _configured_scope(role_rule, fieldname, fallback):
    if role_rule:
        configured = _json_list(getattr(role_rule, fieldname, None))
        if configured:
            return configured
    return fallback()


def _json_list(raw):
    if not raw:
        return []
    try:
        parsed = frappe.parse_json(raw)
    except Exception:
        return []
    if not isinstance(parsed, list):
        return []
    return sorted({str(item).strip() for item in parsed if str(item).strip()})


def _mobile_modules_for_roles(roles):
    role_names = {role.lower() for role in roles}
    modules = {"dashboard"}

    if role_names & FULL_ACCESS_ROLES:
        return [
            "dashboard",
            "executive",
            "sales",
            "collection",
            "purchase",
            "stock",
            "warehouse",
            "quality_control",
            "logistics",
            "approvals",
            "finance",
            "accounting",
            "plantation",
        ]

    if role_names & {"sales manager", "sales user", "sales", "selling user"}:
        modules.update({"sales", "collection"})

    if role_names & {
        "collection user",
        "collection manager",
        "collection",
        "accounts receivable",
    }:
        modules.add("collection")

    if role_names & {
        "purchase manager",
        "purchase user",
        "buying manager",
        "buying user",
        "purchase",
    }:
        modules.add("purchase")

    if role_names & {
        "stock manager",
        "stock user",
        "warehouse",
        "warehouse user",
        "warehouse manager",
    }:
        modules.update({"stock", "warehouse"})

    if role_names & {
        "quality control",
        "quality manager",
        "qc manager",
        "qc user",
    }:
        modules.update({"stock", "warehouse", "quality_control"})

    if role_names & {"logistics manager", "delivery manager", "logistics"}:
        modules.add("logistics")

    if role_names & {"delivery user", "driver"}:
        modules.update({"logistics"})

    if role_names & {"finance manager", "finance user", "finance"}:
        modules.add("finance")

    if role_names & {"accounts manager", "accountant", "accounting"}:
        modules.add("accounting")

    if role_names & {
        "plantation supervisor",
        "plantation manager",
        "plantation",
    }:
        modules.add("plantation")

    if role_names & {
        "sales manager",
        "purchase manager",
        "system manager",
        "company administrator",
        "director",
        "owner",
        "executive",
    }:
        modules.add("approvals")

    if role_names & {"director", "owner", "executive", "company administrator"}:
        modules.add("executive")

    return sorted(modules)
