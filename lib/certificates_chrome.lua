--- Certificates for luakit - chrome page.
--
-- This module allows you to manage saved certificate exceptions
-- at <luakit://certificates/>.
--
-- @module certificates_chrome
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010 Fabian Streitel <karottenreibe@gmail.com>

-- Grab the luakit environment we need
local chrome = require("chrome")
local modes = require("modes")
local add_binds, add_cmds = modes.add_binds, modes.add_cmds

local _M = {}

local html_template = [==[
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Allowed Certificates</title>
    <style type="text/css">
        {style}
    </style>
</head>
<body>
    <header id="page-header">
        <h1>Allowed Certificates</h1>
    </header>
    <div class="content-margin">
    <script>{javascript}</script>
    <table>
        <tr>
            <th>id</th>
            <th>Added</th>
            <th>Host</th>
            <th>Delete</th>
            <th>View</th>
            <th>Copy to Clipboard</th>
            <th>
	        <button class="remove_all" type="button"> Delete All</button>
	    </th>
        </tr> 
        {certtable}  
    </table>
</body>
</html>
]==]

-- Html table template for each saved certificate
local cert_table_template = [=[
<tr class="cert" data-id="{did}">
    <td class="id" data-id="{did}">{did}</td>
    <td class="created" data-id="{did}">{dcreated}</td>
    <td class="host data-id=i"{did}">
        <a class="hosturl" data-id="{did}" href="https://{dhost}">{dhost}</a>
    </td>
    <td>
        <button class="remove" data-id="{did}" type="button">Delete</button>
    </td>
    <td>
        <button class="view" data-id="{did}" type="button">View</button>
    </td>
    <td class="certpem" data-id="{did}" >{dcert}</td>
    <td>
        <button class="copycert" data-id="{did}" type="button">Copy cert</button>
    </td>
</tr>
]=]

--- CSS for certificates chrome page.
-- @type string
-- @readwrite
_M.stylesheet = [==[
    .content-margin {
        position:absolute;
        top: 0;
        bottom:0;
        width: 100%;
        overflow-y:scroll;
        overflow-x:hidden;
    }
    .certpem {	
        display:none;
    }

    th {
        position: sticky;
        top: 0;
        z-index: 10;
        background-color: #ffffff;
    }
    td,th {
        text-align:left;
        padding: 0 15px;
    }
]==]

local main_js = [=[
document.addEventListener('click', event => {
    if (event.target.matches('.remove')) {
	let id = event.target.getAttribute("data-id")
	let host = document.querySelector(`.hosturl[data-id="${id}"]`).innerHTML
	let msg = "Delete certificate for " + host + "?\n\nRequires browser restart to take effect\n"
	msg += "This is a limitation of Webkit"
        if (confirm(msg)) {
            cert_remove(id)
	    document.querySelector(`.cert[data-id="${id}"]`).style.display = 'none' 
        }
    }
    if (event.target.matches('.remove_all')) {
	let msg = "Delete all saved certificates?\n\nRequires browser restart to take effect\n"
	msg += "This is a limitation of Webkit"
        if (confirm(msg)) {
            cert_remove_all()
	    window.location.reload();
        }
    }
    if (event.target.matches('.view')) {
	let id = event.target.getAttribute("data-id")
	let cert = document.querySelector(`.certpem[data-id="${id}"]`).innerHTML
        alert(cert);
    }
    if (event.target.matches('.copycert')) {
	let id = event.target.getAttribute("data-id")
	let cert = document.querySelector(`.certpem[data-id="${id}"]`).innerHTML
        navigator.clipboard.writeText(cert);
    }
})                              
]=]

_M.cert_db_path = luakit.data_dir .. "/allowed_certificates.db"

local export_funcs = {
    cert_remove = function (_,id)
        _M.cert_db:exec("DELETE FROM allowed_certificates where id=?",{id}) 
    end,
    cert_remove_all = function ()
        _M.cert_db:exec("DELETE FROM allowed_certificates") 
    end,
}

--- Get all allowed certificates and update cert_table html template
local function get_saved_certs()
    _M.cert_db = sqlite3{ filename = _M.cert_db_path }
    local rows = _M.cert_db:exec("SELECT * FROM allowed_certificates") 
    local cert_table = {}
    for _, row in ipairs(rows) do
        local d = {
            id = rawget(row, "id"), host = rawget(row, "host"), 
            created = rawget(row, "created"), cert = rawget(row, "cert")
        }
        d.created = os.date("%Y-%m-%d %H:%M:%S", d.created)
        local cert_table_subs = {
            did  = d.id,
            dcreated  = d.created,
            dhost = d.host,
            dcert = d.cert,
        }
    	cert_row = string.gsub(cert_table_template, "{(%w+)}", cert_table_subs)
	table.insert(cert_table,cert_row)
    end
    return cert_table
end

chrome.add("certificates", function ()
    local html_subs = {
        style  = chrome.stylesheet .. _M.stylesheet,
        javascript = main_js,
        certtable = table.concat(get_saved_certs(), "\n"),
    }
    local html = string.gsub(html_template, "{(%w+)}", html_subs)
    return html
end, nil, export_funcs)

--- URI of the certificates chrome page.
-- @type string
-- @readonly
_M.chrome_page = "luakit://certificates/"

add_cmds({
    { ":certificates", [[Open <luakit://certificates> in new tab.]],
        function (w) w:new_tab(_M.chrome_page) end },
})

return _M
