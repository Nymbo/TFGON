-- syntaxchecker.lua
-- A simplified utility to scan Lua files for actual syntax errors only.
-- Ignores style warnings like "missing local", "string concatenation", etc.

local SyntaxChecker = {}

--------------------------------------------------
-- Constants and Configuration
--------------------------------------------------
SyntaxChecker.config = {
    -- Files to ignore entirely or partially
    ignoreFiles = {
        skip = {
            "%.git/",
            "%.vscode/"
        },
        special = {
            ["conf.lua"] = {
                ignoreNilAccess = true,
                ignoreLocalMissing = true
            }
        }
    }
}

--------------------------------------------------
-- State tracking
--------------------------------------------------
SyntaxChecker.state = {
    issues = {},
    contextStack = {},
    scopeVars = {},
    gotoLabels = {},
    gotoJumps = {},
    currentFile = "",
    stats = {
        filesChecked = 0,
        errorCount = 0,
        warningCount = 0,
        filesWithIssues = 0
    }
}

--------------------------------------------------
-- Helper function to add an issue
--------------------------------------------------
local function addIssue(lineNum, text, message, severity)
    table.insert(SyntaxChecker.state.issues, {
        line = lineNum,
        text = text,
        message = message,
        severity = severity or "error" -- Default everything to 'error' now
    })
    
    if severity == "error" then
        SyntaxChecker.state.stats.errorCount = SyntaxChecker.state.stats.errorCount + 1
    else
        SyntaxChecker.state.stats.warningCount = SyntaxChecker.state.stats.warningCount + 1
    end
end

--------------------------------------------------
-- Only keep checks for actual parse errors or 
-- definitely-invalid code.
--------------------------------------------------
local function analyzeSyntax(line, lineNum)
    -- Check for C-style "//" comment
    if line:match("//") and not line:match("http://") and not line:match("https://") then
        addIssue(lineNum, line, "C-style comment detected (use -- instead)", "error")
    end

    -- "else {" -> must be "else" + "end"
    if line:match("else%s*{") then
        addIssue(lineNum, line, "Use 'then' and 'end' instead of { after else", "error")
    end

    -- "if something {" -> must be "if something then ... end"
    if line:match("if.*{%s*$") and not line:match("function") and not line:match("[\"'].-{.-[\"']") then
        addIssue(lineNum, line, "Use 'then' instead of { for if statements", "error")
    end

    -- Check for missing 'then' in if statements
    -- e.g. "if x > 0" but no 'then'
    if line:match("if%s+.+$") and 
       not line:match("then") and 
       not line:match("%-%-") and
       not line:match("{") then
        addIssue(lineNum, line, "Missing 'then' in if statement", "error")
    end

    -- JavaScript-style closing brace
    -- e.g. "}" on a line by itself where Lua expects 'end'
    if line:match("[^-]%s*}%s*$") and          -- there's a '}' near EOL, ignoring lines that start with "--"
       not line:match("^%s*%-%-") and          -- skip comment lines
       not line:match("=%s*function.*}") and   -- skip inline function definitions like x = function() end
       not line:match("=%s*{.*}") then         -- skip table literals like x = { something }
        addIssue(lineNum, line, "JavaScript-style closing brace (use 'end' in Lua)", "error")
    end
end

--------------------------------------------------
-- Main File Checking Function
--------------------------------------------------
function SyntaxChecker.checkFile(filename)
    local file = io.open(filename, "r")
    if not file then
        print("Error: Could not open file " .. filename)
        return false
    end
    
    -- Reset state for each file
    SyntaxChecker.state.issues = {}
    SyntaxChecker.state.contextStack = {}
    SyntaxChecker.state.scopeVars = {}
    SyntaxChecker.state.gotoLabels = {}
    SyntaxChecker.state.gotoJumps = {}
    SyntaxChecker.state.currentFile = filename
    
    -- Attempt to compile the file; if there's a syntax error, it fails here.
    local loaded, errorMsg = loadfile(filename)
    if not loaded then
        local lineNum = tonumber(errorMsg:match(":(%d+):")) or 0
        addIssue(lineNum, "", errorMsg, "error")
        file:close()
        return false
    end
    
    local inMultilineComment = false
    local functionStack = {}
    local bracketStack = {}
    local codeLines = {}
    local lineNum = 0

    file:seek("set", 0)
    for line in file:lines() do
        lineNum = lineNum + 1
        codeLines[lineNum] = line
        
        -- Handle multiline comments
        if line:match("%-%-%[=*%[") then
            inMultilineComment = true
        end
        if inMultilineComment and line:match("%]=*%]") then
            inMultilineComment = false
        end
        
        if not inMultilineComment then
            -- Track function starts/ends
            if line:match("function%s+[%w%.:]-%s*%(") then
                table.insert(functionStack, lineNum)
            end
            if line:match("^%s*end%s*[^-]*$") and #functionStack > 0 then
                table.remove(functionStack)
            end

            -- Track braces for unmatched brace errors
            local openBraces = 0
            local closeBraces = 0
            for _ in line:gmatch("{") do openBraces = openBraces + 1 end
            for _ in line:gmatch("}") do closeBraces = closeBraces + 1 end

            for _ = 1, openBraces do table.insert(bracketStack, lineNum) end
            for _ = 1, closeBraces do 
                if #bracketStack > 0 then
                    table.remove(bracketStack)
                else
                    addIssue(lineNum, line, "Unmatched closing brace", "error")
                end
            end

            -- Check for labeled goto
            local label = line:match("^%s*::([%w_]+)::")
            if label then
                SyntaxChecker.state.gotoLabels[label] = lineNum
            end
            local jump = line:match("goto%s+([%w_]+)")
            if jump then
                table.insert(SyntaxChecker.state.gotoJumps, {label = jump, line = lineNum})
            end

            -- Check syntax (actual parse errors or invalid code style)
            analyzeSyntax(line, lineNum)
        end
    end
    
    file:close()

    -- Check for any unclosed functions
    if #functionStack > 0 then
        for _, funcLine in ipairs(functionStack) do
            addIssue(funcLine, codeLines[funcLine], "Unclosed function", "error")
        end
    end

    -- Check for unmatched braces
    if #bracketStack > 0 then
        for _, braceLine in ipairs(bracketStack) do
            addIssue(braceLine, codeLines[braceLine], "Unclosed brace", "error")
        end
    end

    -- Check for invalid goto labels
    for _, jumpInfo in ipairs(SyntaxChecker.state.gotoJumps) do
        if not SyntaxChecker.state.gotoLabels[jumpInfo.label] then
            addIssue(
                jumpInfo.line,
                codeLines[jumpInfo.line],
                "Invalid goto: label '" .. jumpInfo.label .. "' not found",
                "error"
            )
        end
    end
    
    return #SyntaxChecker.state.issues == 0
end

--------------------------------------------------
-- Directory Scanning Function
--------------------------------------------------
function SyntaxChecker.scanDirectory(directory)
    local commandStr = package.config:sub(1,1) == "\\" and
        'powershell -Command "Get-ChildItem -Path \'' .. directory .. '\' -Filter *.lua -Recurse | ForEach-Object { $_.FullName }"'
        or ('find "' .. directory .. '" -name "*.lua" -type f')

    local handle = io.popen(commandStr)
    if not handle then
        print("Error: Unable to execute directory scan command.")
        return false
    end

    local filesContent = handle:read("*a")
    handle:close()
    local files = {}

    for filename in filesContent:gmatch("[^\r\n]+") do
        filename = filename:gsub("\\", "/")
        local skip = false
        for _, pattern in ipairs(SyntaxChecker.config.ignoreFiles.skip) do
            if filename:match(pattern) then
                skip = true
                break
            end
        end
        if not skip then
            table.insert(files, filename)
        end
    end

    table.sort(files)

    -- Reset stats
    SyntaxChecker.state.stats = {
        filesChecked = 0,
        errorCount = 0,
        warningCount = 0,
        filesWithIssues = 0
    }

    local allPassed = true

    for _, filename in ipairs(files) do
        print("Checking: " .. filename)
        SyntaxChecker.state.stats.filesChecked = SyntaxChecker.state.stats.filesChecked + 1

        local success = SyntaxChecker.checkFile(filename)
        if not success then
            allPassed = false
            SyntaxChecker.state.stats.filesWithIssues = SyntaxChecker.state.stats.filesWithIssues + 1
            
            -- Separate errors from warnings
            local errors, warnings = {}, {}
            for _, issue in ipairs(SyntaxChecker.state.issues) do
                if issue.severity == "error" then
                    table.insert(errors, issue)
                else
                    table.insert(warnings, issue)
                end
            end

            if #errors > 0 then
                print(string.format("\n  ❌ %d error(s):", #errors))
                for _, issue in ipairs(errors) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                    if issue.text and issue.text ~= "" then
                        print("      > " .. issue.text:gsub("^%s+", ""))
                    end
                end
            end

            if #warnings > 0 then
                print(string.format("\n  ⚠️  %d warning(s):", #warnings))
                for _, issue in ipairs(warnings) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                end
            end

            print("") -- Extra blank line
        end
    end

    print("\n=== Syntax Check Summary ===")
    if SyntaxChecker.state.stats.errorCount > 0 then
        print(string.format("❌ Found %d error(s) and %d warning(s) in %d file(s)",
            SyntaxChecker.state.stats.errorCount,
            SyntaxChecker.state.stats.warningCount,
            SyntaxChecker.state.stats.filesWithIssues))
    elseif SyntaxChecker.state.stats.warningCount > 0 then
        print(string.format("⚠️  Found %d warning(s) in %d file(s)",
            SyntaxChecker.state.stats.warningCount,
            SyntaxChecker.state.stats.filesWithIssues))
    else
        print("✅ All files passed syntax check!")
    end

    return allPassed
end

-- Only run if executed directly:
if arg and arg[0]:match("syntaxchecker.lua") then
    print("Scanning Lua files for syntax errors...")
    SyntaxChecker.scanDirectory(".")
end

return SyntaxChecker
