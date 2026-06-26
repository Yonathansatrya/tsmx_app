app_name = "tmsx_mobile"
app_title = "TMSX Mobile"
app_publisher = "TMSX"
app_description = "Mobile backend bridge for the TMSX ERP Flutter app"
app_email = "admin@example.com"
app_license = "MIT"

required_apps = ["frappe", "erpnext"]

after_install = "tmsx_mobile.setup.after_install"

fixtures = [
    {
        "dt": "DocType",
        "filters": [["name", "in", ["TMSX Mobile Settings", "TMSX Mobile Role Module"]]],
    }
]
