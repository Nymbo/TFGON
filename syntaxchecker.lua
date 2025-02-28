-- syntaxchecker.lua
-- A utility to scan Lua files for common syntax errors with improved context awareness

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
    },
    
    -- Known good patterns that shouldn't trigger warnings
    safePatterns = {
        -- Common module paths
        moduleAccess = {
            "^game/",
            "^data/",
            "^conf",
            "^main",
            "%.lua$"
        },
        -- Standard library globals
        knownGlobals = {
            -- Lua standard
            "ipairs", "pairs", "pcall", "xpcall", "error", "assert", "print",
            "tonumber", "tostring", "type", "select", "unpack", "require",
            "loadfile", "load", "rawget", "rawset", "rawequal", "setmetatable",
            "getmetatable", "next", "table", "string", "math", "io", "os",
            "debug", "bit", "arg", "package", "coroutine", "_G", "_VERSION",
            -- LÖVE standard
            "love",
            -- Common LÖVE patterns
            "class", "Class", "Object", "Vector", "Rectangle",
            -- From project
            "Animation", "BoardRegistry", "CardRenderer", "Combat", "DeckManager",
            "DrawSystem", "EffectManager", "GameManager", "InputSystem",
            "SceneManager", "Theme", "Tooltip"
        },
        -- Valid table definitions
        tableContext = {
            "{%s*$",
            "=%s*{",
            "return%s*{",
            "function%s*%b()%s*$"
        },
        -- Known safe initializations
        init = {
            "setmetatable%({},",
            "self%s*=%s*setmetatable%({},",
            -- Add common class/object initialization patterns here
            "local%s+[%w_]+%s*=%s*{",
            "local%s+[%w_]+%s*=%s*require"
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
-- Helper Functions
--------------------------------------------------
local function isModuleAccess(name)
    for _, pattern in ipairs(SyntaxChecker.config.safePatterns.moduleAccess) do
        if name:match(pattern) then return true end
    end
    return false
end

local function isKnownGlobal(name)
    for _, global in ipairs(SyntaxChecker.config.safePatterns.knownGlobals) do
        if name == global then return true end
    end
    return false
end

local function isTableContext(line)
    for _, pattern in ipairs(SyntaxChecker.config.safePatterns.tableContext) do
        if line:match(pattern) then return true end
    end
    return false
end

local function isInitPattern(line)
    for _, pattern in ipairs(SyntaxChecker.config.safePatterns.init) do
        if line:match(pattern) then return true end
    end
    return false
end

local function isStringConcatenation(line)
    -- Look for + operator not between numbers or in math operations
    return line:match("[^%d%.]%s*%+%s*[^%d%.]") and 
           not line:match("^%s*local%s+[%w_]+%s*=%s*[%d%.]+%s*%+") and
           not line:match("[%w_]+%s*=%s*[%d%.]+%s*%+") and
           not line:match("return%s+[%d%.]+%s*%+") and
           not line:match("math%.") -- Skip math operations
end

local function isTableFieldDef(line, contextStack)
    if #contextStack > 0 and contextStack[#contextStack] == "table" then
        return line:match("^%s*[%w_\"'%[]+%s*=%s*.+") or
               line:match("^%s*{") or
               line:match("^%s*%b()%s*$") or 
               line:match("^%s*function%s*%b()") or
               line:match("^%s*%d+%s*$") or
               line:match("^%s*[\"']")
    end
    return false
end

local function getSpecialRules(filename)
    for pattern, rules in pairs(SyntaxChecker.config.ignoreFiles.special) do
        if filename:match(pattern) then return rules end
    end
    return nil
end

local function addIssue(lineNum, text, message, severity)
    table.insert(SyntaxChecker.state.issues, {
        line = lineNum,
        text = text,
        message = message,
        severity = severity or "warning"
    })
    
    if severity == "error" then
        SyntaxChecker.state.stats.errorCount = SyntaxChecker.state.stats.errorCount + 1
    else
        SyntaxChecker.state.stats.warningCount = SyntaxChecker.state.stats.warningCount + 1
    end
end

--------------------------------------------------
-- Analysis Functions
--------------------------------------------------
local function analyzeVariableAccess(line, lineNum, specialRules)
    -- Check variable assignments without 'local'
    if not isTableFieldDef(line, SyntaxChecker.state.contextStack) and 
       not (specialRules and specialRules.ignoreLocalMissing)
    then
        local varName = line:match("^%s*([%w_]+)%s*=")
        if varName and not line:match("^%s*local%s+") and 
           not line:match("^%s*for%s+") and 
           not isKnownGlobal(varName) then
            addIssue(lineNum, line, "Missing 'local' for variable '" .. varName .. "'")
        end
    end
    
    -- Check for potential nil access
    if not (specialRules and specialRules.ignoreNilAccess) then
        for objName in line:gmatch("([%w_]+)%.%w+") do
            if not isInitPattern(line) and
               not isKnownGlobal(objName) and
               not SyntaxChecker.state.scopeVars[objName] and
               not isModuleAccess(objName) then
                addIssue(lineNum, line, "Potential nil access on '" .. objName .. "'")
            end
        end
    end
end

local function analyzeSyntax(line, lineNum)
    -- Empty blocks
    if line:match("then%s*end") or line:match("do%s*end") then
        addIssue(lineNum, line, "Empty block detected")
    end

    -- Unnecessary semicolons
    if line:match(";%s*$") and not line:match("for.*,.*,.*do") then
        addIssue(lineNum, line, "Unnecessary semicolon at line end")
    end

    -- C-style comments
    if line:match("//") then
        addIssue(lineNum, line, "C-style comment detected (use -- instead)", "error")
    end

    -- String concatenation using +
    if isStringConcatenation(line) then
        addIssue(lineNum, line, "Using + for string concatenation (use .. instead)", "error")
    end

    -- Common Lua syntax errors
    if line:match("else%s*{") then
        addIssue(lineNum, line, "Use 'then' instead of { after else", "error")
    end

    if line:match("if.*{%s*$") and not line:match("function") and 
       not line:match("[\"'].-{.-[\"']") then
        addIssue(lineNum, line, "Use 'then' instead of { for if statements", "error")
    end

    -- Check for missing then in if statements
    if line:match("if%s+.+$") and 
       not line:match("then") and 
       not line:match("%-%-") and
       not line:match("{") then
        addIssue(lineNum, line, "Missing 'then' in if statement", "error")
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
    
    -- Reset state
    SyntaxChecker.state.issues = {}
    SyntaxChecker.state.contextStack = {}
    SyntaxChecker.state.scopeVars = {}
    SyntaxChecker.state.gotoLabels = {}
    SyntaxChecker.state.gotoJumps = {}
    SyntaxChecker.state.currentFile = filename
    
    local specialRules = getSpecialRules(filename)
    
    -- Initial syntax check
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
        if line:match("%-%-%[=*%[") then inMultilineComment = true end
        if inMultilineComment and line:match("%]=*%]") then inMultilineComment = false end
        
        if not inMultilineComment then
            -- Track contexts and scopes
            if line:match("function%s+[%w%.:]-%s*%(") then
                table.insert(functionStack, lineNum)
            end
            
            if line:match("^%s*end%s*[^-]*$") and #functionStack > 0 then
                table.remove(functionStack)
            end
            
            if isTableContext(line) then
                table.insert(SyntaxChecker.state.contextStack, "table")
            end
            
            if line:match("%}") and #SyntaxChecker.state.contextStack > 0 then
                table.remove(SyntaxChecker.state.contextStack)
            end
            
            -- Track local variables and labels
            for varName in line:gmatch("local%s+([%w_]+)") do
                SyntaxChecker.state.scopeVars[varName] = true
            end
            
            local label = line:match("^%s*::([%w_]+)::")
            if label then SyntaxChecker.state.gotoLabels[label] = lineNum end
            
            local jump = line:match("goto%s+([%w_]+)")
            if jump then
                table.insert(SyntaxChecker.state.gotoJumps, {label = jump, line = lineNum})
            end
            
            -- Track braces
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
            
            -- Run main analysis
            analyzeVariableAccess(line, lineNum, specialRules)
            analyzeSyntax(line, lineNum)
        end
    end
    
    -- Check for unmatched structures
    if #functionStack > 0 then
        for _, funcLine in ipairs(functionStack) do
            addIssue(funcLine, codeLines[funcLine], "Unclosed function", "error")
        end
    end
    
    if #bracketStack > 0 then
        for _, braceLine in ipairs(bracketStack) do
            addIssue(braceLine, codeLines[braceLine], "Unclosed brace", "error")
        end
    end
    
    for _, jump in ipairs(SyntaxChecker.state.gotoJumps) do
        if not SyntaxChecker.state.gotoLabels[jump.label] then
            addIssue(jump.line, codeLines[jump.line],
                    "Invalid goto: label '" .. jump.label .. "' not found", "error")
        end
    end
    
    file:close()
    return #SyntaxChecker.state.issues == 0
end

--------------------------------------------------
-- Directory Scanning Function
--------------------------------------------------
function SyntaxChecker.scanDirectory(directory)
    local commandStr = package.config:sub(1,1) == "\\" and
        'powershell -Command "Get-ChildItem -Path \'' .. directory .. '\' -Filter *.lua -Recurse | ForEach-Object { $_.FullName }"'
        or 'find "' .. directory .. '" -name "*.lua" -type f'

    local handle = io.popen(commandStr)
    if not handle then
        print("Error: Unable to execute directory scan command.")
        return false
    end

    local files = {}
    for filename in handle:read("*a"):gmatch("[^\r\n]+") do
        filename = filename:gsub("\\", "/")
        local skip = false
        for _, pattern in ipairs(SyntaxChecker.config.ignoreFiles.skip) do
            if filename:match(pattern) then
                skip = true
                break
            end
        end
        if not skip then table.insert(files, filename) end
    end
    table.sort(files)
    handle:close()

    local allPassed = true
    SyntaxChecker.state.stats = {
        filesChecked = 0,
        errorCount = 0,
        warningCount = 0,
        filesWithIssues = 0
    }

    for _, filename in ipairs(files) do
        print("Checking: " .. filename)
        SyntaxChecker.state.stats.filesChecked = SyntaxChecker.state.stats.filesChecked + 1
        
        local success = SyntaxChecker.checkFile(filename)
        if not success then
            allPassed = false
            SyntaxChecker.state.stats.filesWithIssues = SyntaxChecker.state.stats.filesWithIssues + 1
            
            -- Group issues
            local errors = {}
            local warnings = {}
            for _, issue in ipairs(SyntaxChecker.state.issues) do
                if issue.severity == "error" then
                    table.insert(errors, issue)
                else
                    table.insert(warnings, issue)
                end
            end
            
            -- Print errors first
            if #errors > 0 then
                print(string.format("\n  ❌ %d error(s):", #errors))
                for _, issue in ipairs(errors) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                    if issue.text and issue.text ~= "" then
                        print("      > " .. issue.text:gsub("^%s+", ""))
                    end
                end
            end
            
            -- Then warnings (more concise)
            if #warnings > 0 then
                print(string.format("\n  ⚠️  %d warning(s):", #warnings))
                for _, issue in ipairs(warnings) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                end
            end
            
            print("") -- Extra line for readability
        end
    end

    -- Print summary
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

--------------------------------------------------
-- Run the syntax check
--------------------------------------------------
print("Scanning Lua files for syntax errors...")
SyntaxChecker.scanDirectory(".")

return SyntaxChecker