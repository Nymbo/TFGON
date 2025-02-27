-- syntaxchecker.lua
-- A utility to scan Lua files for common syntax errors and provide more detailed reporting

local function checkFile(filename)
    local file = io.open(filename, "r")
    if not file then
        print("Error: Could not open file " .. filename)
        return false
    end

    -- Try to load the file as Lua code to catch syntax errors
    local loaded, errorMsg = loadfile(filename)
    if not loaded then
        -- Extract line number from error message
        local lineNum = errorMsg:match(":(%d+):")
        lineNum = tonumber(lineNum) or 0
        
        print("\nFile: " .. filename)
        print("Lua parser error: " .. errorMsg)
        
        -- Try to show context around the error
        if lineNum > 0 then
            local context = {}
            local currentLine = 0
            file:seek("set", 0)
            
            for line in file:lines() do
                currentLine = currentLine + 1
                if currentLine >= lineNum - 3 and currentLine <= lineNum + 3 then
                    context[#context + 1] = string.format("%s %3d: %s", 
                        currentLine == lineNum and ">" or " ", 
                        currentLine, 
                        line)
                end
            end
            
            print("Context:")
            for _, line in ipairs(context) do
                print(line)
            end
        end
        
        file:close()
        return false
    end

    -- Additional custom checks for common issues that might not cause syntax errors
    local errors = {}
    local lineNum = 0
    local functionStack = {}
    local braceStack = {}
    local inMultilineComment = false
    local codeLines = {}

    file:seek("set", 0)
    for line in file:lines() do
        lineNum = lineNum + 1
        codeLines[lineNum] = line
        
        -- Check for multiline comments
        if line:match("%-%-%[=*%[") then
            inMultilineComment = true
        end
        
        if inMultilineComment and line:match("%]=*%]") then
            inMultilineComment = false
        end
        
        -- Skip checking inside multiline comments
        if not inMultilineComment then
            -- Track function declarations and endings
            if line:match("function%s+[%w%.:]-%s*%(") then
                table.insert(functionStack, lineNum)
            end
            
            if line:match("^%s*end%s*[^-]*$") and #functionStack > 0 then
                table.remove(functionStack)
            end
            
            -- Check for code after 'end'
            if line:match("end%s+[^%-%s]") and not line:match("end%s+if") and 
               not line:match("end%s+function") and not line:match("end%s+while") and
               not line:match("end%s+for") and not line:match("end%s+return") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Code appears after 'end' statement; possibly missing function body or statement"
                })
            end
            
            -- Track brace balancing for tables
            local openBraces = 0
            local closeBraces = 0
            for _ in line:gmatch("{") do openBraces = openBraces + 1 end
            for _ in line:gmatch("}") do closeBraces = closeBraces + 1 end
            
            for i = 1, openBraces do table.insert(braceStack, lineNum) end
            for i = 1, closeBraces do 
                if #braceStack > 0 then
                    table.remove(braceStack)
                else
                    table.insert(errors, {
                        line = lineNum,
                        text = line,
                        message = "Unmatched closing brace '}'",
                        suggestion = "Check for missing opening brace or remove this closing brace"
                    })
                end
            end
            
            -- Check for mismatched { and } that likely should be Lua keywords
            if line:match("else%s*{") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Use 'else' without curly braces; use 'end' to close the block"
                })
            end

            if line:match("if.*{%s*$") and not line:match("function") and not line:match("[\"'].-{.-[\"']") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Use 'then' instead of '{' for if statements"
                })
            end

            if line:match("}%s*$") and not (line:match("=%s*{.*}") or line:match("^%s*{.*}")) 
               and not line:match("[\"'].-}.-[\"']") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Use 'end' instead of '}' to close blocks"
                })
            end

            if line:match("function.*{%s*$") and not line:match("[\"'].-{.-[\"']") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Function definitions don't use curly braces in Lua"
                })
            end

            -- Check for other common issues
            if line:match("=%s*{[^}]*end") and not line:match("[\"'].-{.-end.-[\"']") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Malformed table definition; '{end' is invalid"
                })
            end
            
            -- Check for common typos in variable assignments
            if line:match("(%w+)%s+=%s+") and not line:match("local%s+%w+%s+=") and 
               not line:match("if%s+%w+%s+=") and not line:match("while%s+%w+%s+=") and
               not line:match("for%s+%w+%s+=") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Possible typo in assignment (missing 'local'?)"
                })
            end
            
            -- Check for missing 'then' in if statements
            if line:match("if%s+.+$") and not line:match("then") and not line:match("%-%-") then
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "If statement missing 'then' keyword"
                })
            end
            
            -- Check for common nil access errors
            if line:match("%.(%w+)%s*=") and line:match("^%s*(%w+)%.") then
                local varName = line:match("^%s*(%w+)%.")
                table.insert(errors, {
                    line = lineNum,
                    text = line,
                    message = "Possible nil access - consider initializing " .. varName .. " if it could be nil"
                })
            end
        end
    end
    
    -- Check for unmatched function declarations
    if #functionStack > 0 then
        for _, lineNum in ipairs(functionStack) do
            table.insert(errors, {
                line = lineNum,
                text = codeLines[lineNum],
                message = "Function declaration not closed with 'end'"
            })
        end
    end
    
    -- Check for unmatched braces
    if #braceStack > 0 then
        for _, lineNum in ipairs(braceStack) do
            table.insert(errors, {
                line = lineNum,
                text = codeLines[lineNum],
                message = "Unmatched opening brace '{'"
            })
        end
    end

    file:close()

    if #errors > 0 then
        print("\nFile: " .. filename)
        for _, err in ipairs(errors) do
            print(string.format("Line %d: %s", err.line, err.message))
            print("  > " .. err.text:gsub("^%s+", ""))
            if err.suggestion then
                print("    Suggestion: " .. err.suggestion)
            end
        end
        return false
    end

    return true
end

-- Detect OS for proper file searching
local isWindows = package.config:sub(1, 1) == "\\"

local function scanDirectory(directory)
    local allPassed = true
    local command

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
        table.insert(files, filename)
    end
    table.sort(files)

    local errorCount = 0
    for _, filename in ipairs(files) do
        if not checkFile(filename) then
            allPassed = false
            errorCount = errorCount + 1
        end
    end

    if not allPassed then
        print("\nTotal files with errors: " .. errorCount)
    end

    return allPassed
end

print("Scanning Lua files for syntax errors...")
local result = scanDirectory(".")
if result then
    print("\n✅ All files passed syntax check!")
else
    print("\n❌ Syntax errors found. Please fix the reported issues.")
end