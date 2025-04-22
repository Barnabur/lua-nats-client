package.path = "./?.lua;./?/init.lua;./nats/?.lua;" .. package.path

local tests = {
    require("tests.cli_tests"),
    require("tests.integration_test"),
}

local total, passed = 0, 0

for _, suite in ipairs(tests) do
    for name, fn in pairs(suite) do
        io.write("Running ", name, " ... ")
        total = total + 1
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
            print("[PASS]")
        else
            print("[FAIL]")
            print("   ", err)
        end
    end
end

print(string.format("\n%d/%d tests passed", passed, total))