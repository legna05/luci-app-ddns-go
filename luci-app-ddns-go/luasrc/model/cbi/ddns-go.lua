-- Copyright (C) 2021-2022  sirpdboy  <herboy2008@gmail.com> https://github.com/sirpdboy/luci-app-ddns-go

local m, s ,o

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

-- 在基本设置部分添加密码输入框
o = s:option(Value, "web_password", translate("Web Password"))
o.password = true
o.default = "admin12345"
o.description = translate("Password for web interface login")

o = s:option(Button, "_reset_password", translate("Reset Password"))
o.inputtitle = translate("Apply Password")
o.inputstyle = "apply"
o.description = translate("Apply the password above and restart service")

o.write = function(self, section, value)
    -- 获取表单中的密码值
    local new_password = luci.http.formvalue("cbid.ddns-go.config.web_password")
    local restart = luci.http.formvalue("restart")

    -- 如果是重启确认步骤
    if restart then
        if restart == "1" then
            luci.sys.call("/etc/init.d/ddns-go restart >/dev/null 2>&1")
            m.message = translate("Service restarted")
        else
            m.message = translate("Service not restarted")
        end
        return
    end

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
        -- 成功，显示确认重启弹窗
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
                    <form method="post" style="margin:0;">
                        <input type="hidden" name="restart" value="1" />
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

                    <form method="post" style="margin:0;">
                        <input type="hidden" name="restart" value="0" />
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
        luci.sys.call("/etc/init.d/ddns-go restart >/dev/null 2>&1")
    else
        -- 失败，显示错误信息
        m.message = translate("Reset failed:") .. result
    end
end

m.apply_on_parse = true
m.on_after_apply = function(self,map)
	luci.sys.exec("/etc/init.d/ddns-go restart")
end

return m
