-- Copyright (C) 2021-2022  sirpdboy  <herboy2008@gmail.com> https://github.com/sirpdboy/luci-app-ddns-go

local m, s ,o

local fs = require "nixio.fs"  -- 修正：使用 nixio.fs
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local http = require "luci.http"

-- 在文件顶部添加重启处理
local action = luci.http.formvalue("action")
if action == "restart" then
    luci.sys.call("/etc/init.d/ddns-go restart >/dev/null 2>&1")
    luci.http.redirect(luci.dispatcher.build_url("admin/services/ddns-go"))
    return
end

m = Map("ddns-go")
m.title = translate("DDNS-GO")
m.description = translate("DDNS-GO automatically obtains your public IPv4 or IPv6 address and resolves it to the corresponding domain name service.")..translate("</br>For specific usage, see:")..translate("<a href=\'https://github.com/sirpdboy/luci-app-ddns-go.git' target=\'_blank\'>GitHub @sirpdboy/luci-app-ddns-go </a>")

m:section(SimpleSection).template = "ddns-go/ddns-go_status"

s = m:section(TypedSection, "basic", translate("Global Settings"))
s.addremove = false
s.anonymous = true

o = s:option(Flag,"enabled",translate("Enable"))
o.default = 0

o = s:option(Value, "port",translate("Set the DDNS-TO access port"))
o.datatype = "uinteger"
o.default=9876

o = s:option(Value, "time",translate("update interval"))
o.default=600

o = s:option(Value, "ctimes",translate("Compare with service provider N times intervals"))
o.default=5

o = s:option(Flag,"skipverify",translate("Skip verifying certificates"))
o.default = 0

o = s:option(Value, "dns",translate("Specify DNS resolution server"))
o:value("223.5.5.5", ""..translate("Ali").." DNS (223.5.5.5)")
o:value("223.6.6.6", ""..translate("Ali").." DNS (223.6.6.6)")
o:value("119.29.29.29", ""..translate("Tencent").." DNS (119.29.29.29)")
o:value("1.1.1.1", translate("CloudFlare DNS(1.1.1.1)"))
o:value("8.8.4.4", ""..translate("Google").." DNS(8.8.4.4)")
o:value("8.8.8.8", ""..translate("Google").." DNS(8.8.8.8)")
o.default = "223.5.5.5"

o = s:option(Flag,"noweb",translate("Do not start web services"))
o.default = 0

o = s:option(Value, "delay", translate("Delayed Start (seconds)"))
o.datatype = "and(uinteger,min(0))"
o.default = "60"

-- 在基本设置部分修改密码输入框
o = s:option(Value, "web_password", translate("Web Password"))
o.password = true
o.default = "admin12345"
o.description = translate("Password for web interface login")
o.rmempty = true  -- 允许为空
o.optional = true  -- 可选字段

-- 关键：重写写入方法，不让它保存到UCI
o.write = function(self, section, value)
    -- 不保存到UCI，直接返回
    return
end

-- 重写读取方法，不从UCI读取
o.read = function(self, section)
    -- 返回默认值，不从UCI读取
    return "admin12345"
end

o = s:option(Button, "_reset_password", translate("Reset Password"))
o.inputtitle = translate("Apply Password")
o.inputstyle = "apply"
o.description = translate("Apply the password above and restart service")

o.write = function(self, section, value)
    -- 获取表单中的密码值
    local new_password = luci.http.formvalue("cbid.ddns-go.config.web_password")

    -- 验证密码不为空
    if not new_password or new_password == "" then
        m.message = translate("Error: Password cannot be empty!")
        return
    end

    -- 执行重置密码命令
    local cmd = string.format("/usr/bin/ddns-go -resetPassword %s -c /etc/ddns-go/ddns-go-config.yaml 2>&1",
        new_password)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    -- 检查结果中是否包含"已重置成功"
    if result:find("已重置成功") then
        -- 成功，显示确认重启弹窗，并且YES按钮直接执行重启
        luci.http.write([[
            <div style="
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                z-index: 9999;
                background: white;
                border: 2px solid #4caf50;
                border-radius: 12px;
                padding: 35px 40px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                max-width: 520px;
                width: 90%;
                text-align: center;
                animation: fadeIn 0.3s ease;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            ">
                <style>
                    @keyframes fadeIn {
                        from {
                            opacity: 0;
                            transform: translate(-50%, -55%);
                        }
                        to {
                            opacity: 1;
                            transform: translate(-50%, -50%);
                        }
                    }
                </style>

                <h2 style="
                    color: #2e7d32;
                    margin: 0 0 15px 0;
                    font-size: 28px;
                    font-weight: 600;
                    letter-spacing: -0.5px;
                ">
                    ✅ ]] .. translate("Password Reset Successful") .. [[
                </h2>

                <p style="
                    margin: 0 0 25px 0;
                    color: #555;
                    font-size: 18px;
                    font-weight: 400;
                    line-height: 1.5;
                ">
                    ]] .. translate("Do you want to restart the service?") .. [[
                </p>

                <div style="
                    background: #f8f9fa;
                    border: 1px solid #e9ecef;
                    border-radius: 8px;
                    padding: 20px;
                    margin: 0 0 30px 0;
                    text-align: left;
                    font-family: 'Courier New', monospace;
                    font-size: 14px;
                    line-height: 1.6;
                    color: #495057;
                    max-height: 140px;
                    overflow: auto;
                    white-space: pre-wrap;
                    word-break: break-all;
                ">]] .. result:gsub("\n", "<br />") .. [[</div>

                <div style="
                    display: flex;
                    justify-content: center;
                    gap: 15px;
                    margin-top: 10px;
                ">
                    <form method="post" action="/cgi-bin/luci/admin/services/ddns-go" style="margin:0;">
                        <input type="hidden" name="action" value="restart" />
                        <button type="submit" style="
                            background-color: #4caf50;
                            color: white;
                            border: none;
                            border-radius: 6px;
                            padding: 14px 35px;
                            font-size: 16px;
                            font-weight: 600;
                            cursor: pointer;
                            transition: all 0.2s;
                            box-shadow: 0 2px 5px rgba(76, 175, 80, 0.3);
                        " onmouseover="this.style.backgroundColor='#45a049'" onmouseout="this.style.backgroundColor='#4caf50'">
                            ]] .. translate("YES, RESTART NOW") .. [[
                        </button>
                    </form>

                    <form method="get" action="]] .. luci.http.getenv("REQUEST_URI") .. [[" style="margin:0;">
                        <button type="submit" style="
                            background-color: #6c757d;
                            color: white;
                            border: none;
                            border-radius: 6px;
                            padding: 14px 35px;
                            font-size: 16px;
                            font-weight: 600;
                            cursor: pointer;
                            transition: all 0.2s;
                            box-shadow: 0 2px 5px rgba(108, 117, 125, 0.3);
                        " onmouseover="this.style.backgroundColor='#5a6268'" onmouseout="this.style.backgroundColor='#6c757d'">
                            ]] .. translate("NO, RESTART LATER") .. [[
                        </button>
                    </form>
                </div>

                <!-- 半透明背景遮罩 -->
                <div style="
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0,0,0,0.6);
                    z-index: -1;
                    backdrop-filter: blur(3px);
                "></div>
            </div>
        ]])
    else
        -- 失败，显示错误信息
        m.message = translate("Reset failed:") .. result
    end
end

-- 获取当前版本函数
local function get_current_version()
    local handle = io.popen("/usr/bin/ddns-go -v 2>&1 | head -n1")
    local version_output = handle:read("*l") or ""
    handle:close()

    if version_output == "" then
        return nil
    end

    -- 去除开头的 'v' 字符
    version_output = version_output:gsub("^v", "")
    return version_output
end

-- 检查更新状态函数
local function check_update_status()
    if not fs.access("/usr/bin/ddns-go") then  -- 现在 fs 已经正确定义
        return {
            status = "error",
            message = "ddns-go not found"
        }
    end

    local version_before = get_current_version()

    -- 执行更新检查命令
    local handle = io.popen("/usr/bin/ddns-go -u 2>&1")
    local output = handle:read("*a")
    handle:close()

    if not output or output == "" then
        return {
            status = "error",
            message = "empty response"
        }
    end

    -- 获取更新后的版本
    local version_after = get_current_version()

    -- 解析输出结果
    local update_info = {
        raw_output = output,
        version_before = version_before,
        version_after = version_after,
        has_update = false,
        update_successful = false,
        current_version = "",
        latest_version = "",
        status = "unknown",
        message = output
    }

    -- 判断是否更新成功（版本变化）
    if version_before and version_after and version_before ~= version_after then
        update_info.update_successful = true
        update_info.has_update = false
        update_info.status = "updated"
        update_info.message = string.format("更新成功: %s → %s", version_before, version_after)

    -- 判断是否已是最新版本
    elseif output:find("Current version") and output:find("is the latest") then
        update_info.status = "latest"
        update_info.has_update = false
        local version_match = output:match("v[%d%.]+")
        if version_match then
            update_info.current_version = version_match:gsub("^v", "")
            update_info.latest_version = update_info.current_version
        end
        update_info.message = "已是最新版本 " .. (update_info.current_version or "")

    -- 判断是否有新版本可用
    elseif output:find("new version") and output:find("available") then
        update_info.status = "update_available"
        update_info.has_update = true

        -- 提取版本号
        local current_version_match = output:match("Current version (v[%d%.]+)")
        local new_version_match = output:match("new version (v[%d%.]+)")

        if current_version_match then
            update_info.current_version = current_version_match:gsub("^v", "")
        elseif version_before then
            update_info.current_version = version_before
        end

        if new_version_match then
            update_info.latest_version = new_version_match:gsub("^v", "")
        end

        update_info.message = "有新版本可用: " .. (update_info.latest_version or "")

    -- 判断下载是否失败
    elseif output:find("download") and output:find("failed") then
        update_info.status = "download_failed"
        update_info.has_update = false
        update_info.message = "下载更新失败"

    -- 判断检查是否失败
    elseif output:find("check") and output:find("failed") or
           output:find("Error") or
           output:find("error") or
           output:find("Exception") or
           output:find("rate limit") then
        update_info.status = "check_failed"
        update_info.has_update = false
        update_info.message = "检查更新失败: " .. output
    end

    return update_info
end

-- 版本信息显示
o = s:option(DummyValue, "_current_version", translate("Current Version"))
o.rawhtml = true
o.cfgvalue = function(self, section)
    local version = get_current_version()
    if version then
        return '<span id="current_version" style="color:green">v' .. version .. '</span>'
    else
        return '<span style="color:orange">' .. translate("Unknown") .. '</span>'
    end
end

-- 更新按钮
o = s:option(Button, "_update", translate("Update kernel"))
o.inputtitle = translate("Check Update")
o.inputstyle = "apply"
o.description = translate("Check for updates and update DDNS-GO")

-- 更新按钮（只修改了这一部分，其他代码保持不变）
o.write = function(self, section, value)

    -- 执行更新检查
    local info = check_update_status()

    if info then
        if info.status == "updated" or info.update_successful then
            -- 更新成功（保持原有的完整弹窗）
            local html = [[
                <div style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #4caf50;
                    border-radius: 12px;
                    padding: 30px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 450px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                    </style>

                    <h2 style="color: #2e7d32; margin: 0 0 20px 0; font-size: 24px;">
                        ✅ ]] .. translate("Update Successful") .. [[
                    </h2>

                    <div style="
                        background: #f8f9fa;
                        border: 1px solid #e9ecef;
                        border-radius: 6px;
                        padding: 15px;
                        margin: 0 0 20px 0;
                        text-align: left;
                        font-family: monospace;
                        font-size: 13px;
                        max-height: 150px;
                        overflow: auto;
                        white-space: pre-wrap;
                        word-break: break-all;
                    ">]] .. (info.message or ""):gsub("\n", "<br />") .. [[</div>

                    <form method="post" action="]] .. http.getenv("REQUEST_URI") .. [[" style="margin:0;">
                        <button type="submit" style="
                            background-color: #4caf50;
                            color: white;
                            border: none;
                            border-radius: 6px;
                            padding: 12px 30px;
                            font-size: 16px;
                            cursor: pointer;
                        ">]] .. translate("OK") .. [[</button>
                    </form>

                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.5);
                        z-index: -1;
                    "></div>
                </div>
            ]]

            http.write(html)
            return

        elseif info.status == "update_available" then
            -- 有可用更新 - 改为居中浮窗，3秒后自动消失
            local html = [[
                <div id="auto_notify" style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #2196f3;
                    border-radius: 12px;
                    padding: 25px 35px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 400px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                        @keyframes fadeOut {
                            from { opacity: 1; transform: translate(-50%, -50%); }
                            to { opacity: 0; transform: translate(-50%, -55%); }
                        }
                    </style>
                    <span style="font-size: 48px; display: block; margin-bottom: 15px;">↻</span>
                    <h3 style="color: #0b5e9e; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Update Available") .. [[</h3>
                    <p style="margin: 0; color: #666; font-size: 16px;">]] .. translate("Update available: v") .. (info.latest_version or "") .. [[</p>
                    <p style="margin: 5px 0 0 0; color: #999; font-size: 14px;">]] .. translate("Click again to update") .. [[</p>
                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.3);
                        z-index: -1;
                    "></div>
                </div>
                <script>
                    setTimeout(function() {
                        var el = document.getElementById('auto_notify');
                        if (el) {
                            el.style.animation = 'fadeOut 0.3s ease';
                            setTimeout(function() { el.remove(); }, 300);
                        }
                    }, 3000);
                </script>
            ]]
            http.write(html)
            return

        elseif info.status == "latest" then
            -- 已是最新版本 - 改为居中浮窗，3秒后自动消失
            local html = [[
                <div id="auto_notify" style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #4caf50;
                    border-radius: 12px;
                    padding: 25px 35px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 400px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                        @keyframes fadeOut {
                            from { opacity: 1; transform: translate(-50%, -50%); }
                            to { opacity: 0; transform: translate(-50%, -55%); }
                        }
                    </style>
                    <span style="font-size: 48px; display: block; margin-bottom: 15px;">✓</span>
                    <h3 style="color: #2e7d32; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Latest Version") .. [[</h3>
                    <p style="margin: 0; color: #666; font-size: 16px;">]] .. translate("Already latest version.") .. [[</p>
                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.3);
                        z-index: -1;
                    "></div>
                </div>
                <script>
                    setTimeout(function() {
                        var el = document.getElementById('auto_notify');
                        if (el) {
                            el.style.animation = 'fadeOut 0.3s ease';
                            setTimeout(function() { el.remove(); }, 300);
                        }
                    }, 3000);
                </script>
            ]]
            http.write(html)
            return

        elseif info.status == "download_failed" then
            -- 下载失败 - 改为居中浮窗，3秒后自动消失
            local html = [[
                <div id="auto_notify" style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #f44336;
                    border-radius: 12px;
                    padding: 25px 35px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 400px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                        @keyframes fadeOut {
                            from { opacity: 1; transform: translate(-50%, -50%); }
                            to { opacity: 0; transform: translate(-50%, -55%); }
                        }
                    </style>
                    <span style="font-size: 48px; display: block; margin-bottom: 15px;">✗</span>
                    <h3 style="color: #d32f2f; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Download Failed") .. [[</h3>
                    <p style="margin: 0; color: #666; font-size: 14px; max-height: 100px; overflow: auto;">]] .. (info.message or ""):gsub("\n", "<br />") .. [[</p>
                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.3);
                        z-index: -1;
                    "></div>
                </div>
                <script>
                    setTimeout(function() {
                        var el = document.getElementById('auto_notify');
                        if (el) {
                            el.style.animation = 'fadeOut 0.3s ease';
                            setTimeout(function() { el.remove(); }, 300);
                        }
                    }, 3000);
                </script>
            ]]
            http.write(html)
            return

        elseif info.status == "check_failed" then
            -- 检查失败 - 改为居中浮窗，3秒后自动消失
            local html = [[
                <div id="auto_notify" style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #ff9800;
                    border-radius: 12px;
                    padding: 25px 35px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 400px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                        @keyframes fadeOut {
                            from { opacity: 1; transform: translate(-50%, -50%); }
                            to { opacity: 0; transform: translate(-50%, -55%); }
                        }
                    </style>
                    <span style="font-size: 48px; display: block; margin-bottom: 15px;">⚠️</span>
                    <h3 style="color: #c66900; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Check Failed") .. [[</h3>
                    <p style="margin: 0; color: #666; font-size: 14px; max-height: 100px; overflow: auto;">]] .. (info.message or ""):gsub("\n", "<br />") .. [[</p>
                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.3);
                        z-index: -1;
                    "></div>
                </div>
                <script>
                    setTimeout(function() {
                        var el = document.getElementById('auto_notify');
                        if (el) {
                            el.style.animation = 'fadeOut 0.3s ease';
                            setTimeout(function() { el.remove(); }, 300);
                        }
                    }, 3000);
                </script>
            ]]
            http.write(html)
            return

        else
            -- 其他状态 - 改为居中浮窗，3秒后自动消失
            local html = [[
                <div id="auto_notify" style="
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    z-index: 9999;
                    background: white;
                    border: 2px solid #9e9e9e;
                    border-radius: 12px;
                    padding: 25px 35px;
                    box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                    max-width: 400px;
                    width: 90%;
                    text-align: center;
                    animation: fadeIn 0.3s ease;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                ">
                    <style>
                        @keyframes fadeIn {
                            from { opacity: 0; transform: translate(-50%, -55%); }
                            to { opacity: 1; transform: translate(-50%, -50%); }
                        }
                        @keyframes fadeOut {
                            from { opacity: 1; transform: translate(-50%, -50%); }
                            to { opacity: 0; transform: translate(-50%, -55%); }
                        }
                    </style>
                    <span style="font-size: 48px; display: block; margin-bottom: 15px;">ℹ️</span>
                    <h3 style="color: #616161; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Update Status") .. [[</h3>
                    <p style="margin: 0; color: #666; font-size: 14px; max-height: 100px; overflow: auto;">]] .. (info.message or ""):gsub("\n", "<br />") .. [[</p>
                    <div style="
                        position: fixed;
                        top: 0;
                        left: 0;
                        right: 0;
                        bottom: 0;
                        background: rgba(0,0,0,0.3);
                        z-index: -1;
                    "></div>
                </div>
                <script>
                    setTimeout(function() {
                        var el = document.getElementById('auto_notify');
                        if (el) {
                            el.style.animation = 'fadeOut 0.3s ease';
                            setTimeout(function() { el.remove(); }, 300);
                        }
                    }, 3000);
                </script>
            ]]
            http.write(html)
            return
        end
    else
        -- 失败，显示错误信息 - 改为居中浮窗，3秒后自动消失
        local html = [[
            <div id="auto_notify" style="
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                z-index: 9999;
                background: white;
                border: 2px solid #f44336;
                border-radius: 12px;
                padding: 25px 35px;
                box-shadow: 0 10px 40px rgba(0,0,0,0.3);
                max-width: 400px;
                width: 90%;
                text-align: center;
                animation: fadeIn 0.3s ease;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            ">
                <style>
                    @keyframes fadeIn {
                        from { opacity: 0; transform: translate(-50%, -55%); }
                        to { opacity: 1; transform: translate(-50%, -50%); }
                    }
                    @keyframes fadeOut {
                        from { opacity: 1; transform: translate(-50%, -50%); }
                        to { opacity: 0; transform: translate(-50%, -55%); }
                    }
                </style>
                <span style="font-size: 48px; display: block; margin-bottom: 15px;">❌</span>
                <h3 style="color: #d32f2f; margin: 0 0 10px 0; font-size: 22px;">]] .. translate("Error") .. [[</h3>
                <p style="margin: 0; color: #666; font-size: 14px;">]] .. translate("Failed to check for updates.") .. [[</p>
                <div style="
                    position: fixed;
                    top: 0;
                    left: 0;
                    right: 0;
                    bottom: 0;
                    background: rgba(0,0,0,0.3);
                    z-index: -1;
                "></div>
            </div>
            <script>
                setTimeout(function() {
                    var el = document.getElementById('auto_notify');
                    if (el) {
                        el.style.animation = 'fadeOut 0.3s ease';
                        setTimeout(function() { el.remove(); }, 300);
                    }
                }, 3000);
            </script>
        ]]
        http.write(html)
        return
    end
end

m.apply_on_parse = true
m.on_after_apply = function(self,map)
	luci.sys.exec("/etc/init.d/ddns-go restart")
end

return m
