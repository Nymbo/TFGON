-- syntaxchecker.lua
-- A smarter utility to scan Lua files for common syntax errors with improved context awareness

local SyntaxChecker = {}

-- Configuration for the checker
SyntaxChecker.config = {
    -- Files to ignore entirely or partially
    ignoreFiles = {
        -- File patterns to completely skip
        skip = {
            "%.git/",
            "%.vscode/"
        },
        -- Files with special rules
        special = {
            ["conf.lua"] = {
                ignoreNilAccess = true,  -- Ignore nil access in conf.lua (t is provided by LÖVE)
                ignoreLocalMissing = true -- Ignore missing 'local' in conf.lua
            }
        }
    },
    -- Known globals provided by environment or frameworks
    knownGlobals = {
        -- Lua standard
        "ipairs", "pairs", "pcall", "xpcall", "error", "assert", "print", "tonumber", "tostring",
        "type", "select", "unpack", "require", "loadfile", "load", "rawget", "rawset", "rawequal",
        "setmetatable", "getmetatable", "next", "table", "string", "math", "io", "os", "debug", "bit",
        "arg", "package", "coroutine", "_G", "_VERSION", "collectgarbage", "dofile", "gcinfo", 
        "getfenv", "setfenv", "newproxy", "module",
        
        -- LÖVE standard
        "love", 
        
        -- Common in many LÖVE projects
        "class", "Class", "Object", "Vector", "Rectangle", 
        
        -- From your specific project
        "Animation", "BoardRegistry", "CardRenderer", "Combat", "DeckManager", "DrawSystem", "EffectManager",
        "GameManager", "InputSystem", "SceneManager", "Theme", "Tooltip"
    },
    
    -- Table field definitions shouldn't trigger local warnings
    tableContextPatterns = {
        "{%s*$",          -- Open brace at end of line
        "=%s*{",          -- Assignment with open brace
        "return%s*{",     -- Return statement with open brace
        "function%s*%b()%s*$" -- Function definition at end of line
    },
    
    -- Patterns for constructors/initializers where self isn't nil
    initializationPatterns = {
        "setmetatable%({},",  -- Common object creation pattern
        "self%s*=%s*setmetatable%({},", -- Explicit self initialization 
    }
}

-- Table to keep track of found issues
SyntaxChecker.issues = {}

-- Counter for table contexts to detect table field assignments
SyntaxChecker.contextStack = {}

-- Table to track locally declared variables in scope
SyntaxChecker.scopeVars = {}

-- Table to track globals defined or used
SyntaxChecker.globals = {
    defined = {},
    used = {}
}

-- Keep track of goto labels
SyntaxChecker.gotoLabels = {}
SyntaxChecker.gotoJumps = {}

-- Current file being checked
SyntaxChecker.currentFile = ""

-- Caches regex pattern for table fields
local function isTableFieldDefinition(line, contextStack)
    -- We're within a table constructor
    if #contextStack > 0 and contextStack[#contextStack] == "table" then
        -- Basic pattern for table field: key = value or just a value
        return line:match("^%s*[%w_\"'%[]+%s*=%s*.+") or
               line:match("^%s*{") or
               line:match("^%s*%b()%s*$") or 
               line:match("^%s*function%s*%b()") or
               line:match("^%s*%d+%s*$") or
               line:match("^%s*[\"']")
    end
    return false
end

-- Check if the line starts a table definition context
local function startsTableContext(line)
    for _, pattern in ipairs(SyntaxChecker.config.tableContextPatterns) do
        if line:match(pattern) then
            return true
        end
    end
    return false
end

-- Check if the line is an initialization pattern where self won't be nil
local function isInitializationPattern(line) 
    for _, pattern in ipairs(SyntaxChecker.config.initializationPatterns) do
        if line:match(pattern) then
            return true
        end
    end
    return false
end

-- Check if a variable name is a known global
local function isKnownGlobal(name)
    for _, global in ipairs(SyntaxChecker.config.knownGlobals) do
        if name == global then
            return true
        end
    end
    return false
end

-- Check if we should apply special rules to this file
local function getSpecialRules(filename)
    for pattern, rules in pairs(SyntaxChecker.config.ignoreFiles.special) do
        if filename:match(pattern) then
            return rules
        end
    end
    return nil
end

-- Add an issue to the report
local function addIssue(lineNum, text, message, severity, suggestion)
    table.insert(SyntaxChecker.issues, {
        line = lineNum,
        text = text,
        message = message,
        severity = severity or "warning", -- "error", "warning", "info"
        suggestion = suggestion
    })
end

-- Analyze a line for variables being accessed or assigned
local function analyzeVariableAccess(line, lineNum, specialRules)
    -- Check variable assignments without 'local'
    if not isTableFieldDefinition(line, SyntaxChecker.contextStack) and 
       not (specialRules and specialRules.ignoreLocalMissing) then
        
        -- Look for direct assignments not inside a table definition
        local varName = line:match("^%s*([%w_]+)%s*=")
        if varName and not line:match("^%s*local%s+") and 
           not line:match("^%s*for%s+") and 
           not isKnownGlobal(varName) then
            
            addIssue(lineNum, line, "Possible global variable assignment of '" .. varName .. "' (missing 'local'?)", 
                    "warning", "Add 'local' if this is meant to be scoped locally")
            
            -- Track global definition
            SyntaxChecker.globals.defined[varName] = true
        end
    end
    
    -- Check for possible nil access (obj.property when obj could be nil)
    if not (specialRules and specialRules.ignoreNilAccess) then
        -- Find patterns like "something.property" where something might be nil
        for objName in line:gmatch("([%w_]+)%.%w+") do
            -- Skip if we're in an initialization or if it's a known global
            if not isInitializationPattern(line) and 
               not isKnownGlobal(objName) and
               not SyntaxChecker.scopeVars[objName] then
                
                addIssue(lineNum, line, "Possible nil access on '" .. objName .. "' - consider initialization check", 
                        "warning", "Add a check like 'if " .. objName .. " then' or initialize the variable")
            end
        end
    end
end

-- Check a file for various syntax and style issues
function SyntaxChecker.checkFile(filename)
    local file = io.open(filename, "r")
    if not file then
        print("Error: Could not open file " .. filename)
        return false
    end
    
    -- Reset state for this file
    SyntaxChecker.issues = {}
    SyntaxChecker.contextStack = {}
    SyntaxChecker.scopeVars = {}
    SyntaxChecker.gotoLabels = {}
    SyntaxChecker.gotoJumps = {}
    SyntaxChecker.currentFile = filename
    
    -- Get special rules for this file if any
    local specialRules = getSpecialRules(filename)
    
    -- Check if the file has syntax errors
    local loaded, errorMsg = loadfile(filename)
    if not loaded then
        -- Extract line number from error message
        local lineNum = errorMsg:match(":(%d+):")
        lineNum = tonumber(lineNum) or 0
        
        -- Add as a syntax error issue
        addIssue(lineNum, "", errorMsg, "error")
        
        -- Try to show context around the error
        if lineNum > 0 then
            local context = {}
            local currentLine = 0
            file:seek("set", 0)
            
            for line in file:lines() do
                currentLine = currentLine + 1
                if currentLine >= lineNum - 3 and currentLine <= lineNum + 3 then
                    if currentLine == lineNum then
                        -- Store the error line
                        SyntaxChecker.issues[#SyntaxChecker.issues].text = line
                    end
                    table.insert(context, string.format("%s %3d: %s", 
                        currentLine == lineNum and ">" or " ", 
                        currentLine, 
                        line))
                end
            end
            
            -- Store context information
            SyntaxChecker.issues[#SyntaxChecker.issues].context = context
        end
        
        file:close()
        return false
    end
    
    -- Initialize state for more thorough checking
    local inMultilineComment = false
    local inFunctionBody = false
    local bracketStack = {}
    local functionStack = {}
    local codeLines = {}
    local lineNum = 0
    
    file:seek("set", 0)
    for line in file:lines() do
        lineNum = lineNum + 1
        codeLines[lineNum] = line
        
        -- Handle multiline comments
        if line:match("%-%-%[=*%[") and not inMultilineComment then
            inMultilineComment = true
        end
        
        if inMultilineComment and line:match("%]=*%]") then
            inMultilineComment = false
        end
        
        -- Skip checking in multiline comments
        if not inMultilineComment then
            -- Track function declarations
            if line:match("function%s+[%w%.:]-%s*%(") then
                table.insert(functionStack, lineNum)
                inFunctionBody = true
            end
            
            -- Track end of functions
            if line:match("^%s*end%s*[^-]*$") and #functionStack > 0 then
                table.remove(functionStack)
                inFunctionBody = #functionStack > 0
            end
            
            -- Keep track of table constructors for context
            if startsTableContext(line) then
                table.insert(SyntaxChecker.contextStack, "table")
            end
            
            if line:match("%}") and #SyntaxChecker.contextStack > 0 and 
               SyntaxChecker.contextStack[#SyntaxChecker.contextStack] == "table" then
                table.remove(SyntaxChecker.contextStack)
            end
            
            -- Track 'local' declarations to check scope
            for varName in line:gmatch("local%s+([%w_]+)") do
                SyntaxChecker.scopeVars[varName] = true
            end
            
            -- Track goto labels (::label::)
            local label = line:match("^%s*::([%w_]+)::")
            if label then
                SyntaxChecker.gotoLabels[label] = lineNum
            end
            
            -- Track goto jumps
            local jump = line:match("goto%s+([%w_]+)")
            if jump then
                table.insert(SyntaxChecker.gotoJumps, {label = jump, line = lineNum})
            end
            
            -- Check for code after 'end'
            if line:match("end%s+[^%-%s]") and 
               not line:match("end%s+if") and 
               not line:match("end%s+function") and 
               not line:match("end%s+while") and
               not line:match("end%s+for") and 
               not line:match("end%s+return") then
                
                addIssue(lineNum, line, "Code appears after 'end' statement; possibly missing a separator", 
                        "warning", "Add a semicolon or line break after 'end'")
            end
            
            -- Track brace balancing for tables
            local openBraces = 0
            local closeBraces = 0
            
            for _ in line:gmatch("{") do openBraces = openBraces + 1 end
            for _ in line:gmatch("}") do closeBraces = closeBraces + 1 end
            
            for i = 1, openBraces do table.insert(bracketStack, lineNum) end
            for i = 1, closeBraces do 
                if #bracketStack > 0 then
                    table.remove(bracketStack)
                else
                    addIssue(lineNum, line, "Unmatched closing brace '}'", 
                            "error", "Check for missing opening brace or remove this closing brace")
                end
            end
            
            -- Check for mismatched { and } that likely should be Lua keywords
            if line:match("else%s*{") then
                addIssue(lineNum, line, "Use 'else' without curly braces; use 'then' and 'end'", 
                        "error", "Lua uses 'else ... end', not 'else { ... }'")
            end
            
            if line:match("if.*{%s*$") and not line:match("function") and 
               not line:match("[\"'].-{.-[\"']") then
                addIssue(lineNum, line, "Use 'then' instead of '{' for if statements", 
                        "error", "Lua uses 'if condition then ... end' syntax")
            end
            
            if line:match("}%s*$") and 
               not (line:match("=%s*{.*}") or line:match("^%s*{.*}") or line:match("return.*{.*}")) and
               not line:match("[\"'].-}.-[\"']") then
                addIssue(lineNum, line, "Use 'end' instead of '}' to close blocks", 
                        "error", "Lua uses 'end' to close code blocks, not '}'")
            end
            
            if line:match("function.*{%s*$") and not line:match("[\"'].-{.-[\"']") then
                addIssue(lineNum, line, "Function definitions don't use curly braces in Lua", 
                        "error", "Use 'function name() ... end' syntax")
            end
            
            -- Check for other common issues
            if line:match("=%s*{[^}]*end") and not line:match("[\"'].-{.-end.-[\"']") then
                addIssue(lineNum, line, "Malformed table definition; '{end' is invalid", 
                        "error", "Check for missing closing brace")
            end
            
            -- Check for missing 'then' in if statements
            if line:match("if%s+.+$") and 
               not line:match("then") and 
               not line:match("%-%-") and
               not line:match("{") then
                addIssue(lineNum, line, "If statement missing 'then' keyword", 
                        "error", "Lua requires 'then' after the condition in an if statement")
            end
            
            -- Analyze variable access and assignments
            analyzeVariableAccess(line, lineNum, specialRules)
        end
    end
    
    -- Check for unmatched function declarations
    if #functionStack > 0 then
        for _, lineNum in ipairs(functionStack) do
            addIssue(lineNum, codeLines[lineNum], "Function declaration not closed with 'end'", 
                    "error", "Add a matching 'end' statement")
        end
    end
    
    -- Check for unmatched braces
    if #bracketStack > 0 then
        for _, lineNum in ipairs(bracketStack) do
            addIssue(lineNum, codeLines[lineNum], "Unmatched opening brace '{'", 
                    "error", "Add a matching '}' or remove this opening brace")
        end
    end
    
    -- Check for goto jumps without matching labels
    for _, jump in ipairs(SyntaxChecker.gotoJumps) do
        if not SyntaxChecker.gotoLabels[jump.label] then
            addIssue(jump.line, codeLines[jump.line], 
                    "Goto statement jumps to non-existent label '" .. jump.label .. "'", 
                    "error", "Add a matching label ::'" .. jump.label .. "':: or correct the label name")
        end
    end
    
    file:close()
    return #SyntaxChecker.issues == 0
end

-- Scan a directory for Lua files recursively
function SyntaxChecker.scanDirectory(directory)
    local allPassed = true
    local command
    local isWindows = package.config:sub(1, 1) == "\\"

    if isWindows then
        -- Windows: Use PowerShell to find .lua files
        command = 'powershell -Command "Get-ChildItem -Path \'' .. directory .. '\' -Filter *.lua -Recurse | ForEach-Object { $_.FullName }"'
    else
        -- Linux/macOS: Use find command
        command = 'find "' .. directory .. '" -name "*.lua" -type f'
    end

    local handle = io.popen(command)
    if not handle then
        print("Error: Unable to execute directory scan command.")
        return false
    end

    local result = handle:read("*a")
    handle:close()

    -- Sort filenames to process them in a consistent order
    local files = {}
    for filename in result:gmatch("[^\r\n]+") do
        filename = filename:gsub("\\", "/") -- Normalize path slashes
        
        -- Check if this file should be skipped
        local skipFile = false
        for _, pattern in ipairs(SyntaxChecker.config.ignoreFiles.skip) do
            if filename:match(pattern) then
                skipFile = true
                break
            end
        end
        
        if not skipFile then
            table.insert(files, filename)
        end
    end
    table.sort(files)

    -- Track file stats
    local errorCount = 0
    local filesWithIssues = 0
    local totalIssueCount = 0
    
    -- Analyze each file
    for _, filename in ipairs(files) do
        print("Checking: " .. filename)
        local success = SyntaxChecker.checkFile(filename)
        
        if not success then
            allPassed = false
            filesWithIssues = filesWithIssues + 1
            
            -- Print issues for this file
            print("\nFile: " .. filename)
            
            -- Group issues by severity
            local errorIssues = {}
            local warningIssues = {}
            
            -- Separate errors from warnings
            for _, issue in ipairs(SyntaxChecker.issues) do
                if issue.severity == "error" then
                    table.insert(errorIssues, issue)
                else
                    table.insert(warningIssues, issue)
                end
                
                totalIssueCount = totalIssueCount + 1
            end
            
            -- Print errors first
            if #errorIssues > 0 then
                print(string.format("  ❌ %d error(s):", #errorIssues))
                for _, issue in ipairs(errorIssues) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                    print("      > " .. issue.text:gsub("^%s+", ""))
                    if issue.suggestion then
                        print("        Suggestion: " .. issue.suggestion)
                    end
                    -- Print context if available
                    if issue.context then
                        print("        Context:")
                        for _, line in ipairs(issue.context) do
                            print("          " .. line)
                        end
                    end
                end
                
                -- Count unique syntax errors
                errorCount = errorCount + #errorIssues
            end
            
            -- Then warnings
            if #warningIssues > 0 then
                print(string.format("  ⚠️ %d warning(s):", #warningIssues))
                for _, issue in ipairs(warningIssues) do
                    print(string.format("    Line %d: %s", issue.line, issue.message))
                    print("      > " .. issue.text:gsub("^%s+", ""))
                    if issue.suggestion then
                        print("        Suggestion: " .. issue.suggestion)
                    end
                end
            end
            
            print("") -- Extra line for readability
        end
    end

    -- Print summary
    print("\n=== Syntax Check Summary ===")
    if errorCount > 0 then
        print(string.format("❌ Found %d error(s) in %d file(s)", errorCount, filesWithIssues))
    else if totalIssueCount > 0 then
        print(string.format("⚠️ Found %d warning(s) in %d file(s)", totalIssueCount, filesWithIssues))
    else
        print("✅ All files passed syntax check!")
    end
    end

    return allPassed
end

-- Run the syntax check on current directory
print("Scanning Lua files for syntax errors...")
SyntaxChecker.scanDirectory(".")