--[[

    Dev : NexusScripts

]]

local lexer = {}

lexer.TOKEN_TYPES = {
    KEYWORD = "KEYWORD",
    IDENTIFIER = "IDENTIFIER",
    NUMBER = "NUMBER",
    STRING = "STRING", 
    NIL = "NIL",
    TRUE = "TRUE",
    FALSE = "FALSE",
    ADD = "ADD",
    SUB = "SUB",  
    MUL = "MUL", 
    DIV = "DIV", 
    IDIV = "IDIV",
    MOD = "MOD",
    POW = "POW",
    BAND = "BAND",
    BOR = "BOR",
    BXOR = "BXOR",
    SHL = "SHL",
    SHR = "SHR",
    CONCAT = "CONCAT",
    LEN = "LEN",
    LT = "LT",
    LE = "LE",
    GT = "GT",
    GE = "GE",
    EQ = "EQ",
    NE = "NE",
    ASSIGN = "ASSIGN",
    LPAREN = "LPAREN",
    RPAREN = "RPAREN",   
    LBRACKET = "LBRACKET", 
    RBRACKET = "RBRACKET", 
    LBRACE = "LBRACE",  
    RBRACE = "RBRACE",   
    COMMA = "COMMA", 
    SEMI = "SEMI",
    COLON = "COLON",
    DOUBLE_COLON = "DOUBLE_COLON",
    DOT = "DOT",
    VARARG = "VARARG",
    EOF = "EOF"
}

lexer.KEYWORDS = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["goto"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true
}

function lexer.create_token(type, value, line, col, raw)
    return {
        type = type,
        value = value,
        line = line or 0,
        col = col or 0,
        raw = raw
    }
end

local function skip_whitespace(code, pos, line, col)
    local c
    while pos <= #code do
        c = code:sub(pos, pos)
        if c == ' ' or c == '\t' or c == '\v' or c == '\f' then
            pos = pos + 1
            col = col + 1
        elseif c == '\n' then
            pos = pos + 1
            line = line + 1
            col = 1
        elseif c == '\r' then
            pos = pos + 1
            if pos <= #code and code:sub(pos, pos) == '\n' then
                pos = pos + 1
            end
            line = line + 1
            col = 1
        else
            break
        end
    end
    return pos, line, col
end

local function skip_comments(code, pos, line, col)
    if pos + 1 <= #code and code:sub(pos, pos + 1) == "--" then
        pos = pos + 2
        col = col + 2

        if pos <= #code and code:sub(pos, pos) == "[" then
            local pos2 = pos + 1
            while pos2 <= #code and code:sub(pos2, pos2) == "=" do
                pos2 = pos2 + 1
            end
            if pos2 <= #code and code:sub(pos2, pos2) == "[" then
                local level = pos2 - pos - 1
                pos = pos2 + 1
                col = col + level + 2
                
                while pos <= #code do
                    if code:sub(pos, pos) == "\n" then
                        line = line + 1
                        col = 1
                        pos = pos + 1
                    elseif code:sub(pos, pos) == "]" then
                        local found = true
                        if pos + level + 1 <= #code then
                            for i = 1, level do
                                if code:sub(pos + i, pos + i) ~= "=" then
                                    found = false
                                    break
                                end
                            end
                            if found and code:sub(pos + level + 1, pos + level + 1) == "]" then
                                pos = pos + level + 2
                                col = col + level + 2
                                return pos, line, col, true
                            end
                        end
                        pos = pos + 1
                        col = col + 1
                    else
                        pos = pos + 1
                        col = col + 1
                    end
                end
                return pos, line, col, true
            end
        end

        while pos <= #code and code:sub(pos, pos) ~= "\n" and code:sub(pos, pos) ~= "\r" do
            pos = pos + 1
            col = col + 1
        end
        return pos, line, col, true
    end
    return pos, line, col, false
end

local function process_nested_comments(code, pos, line, col)
    if pos + 1 <= #code and code:sub(pos, pos + 1) == "--" then
        pos = pos + 2
        col = col + 2
        
        if pos <= #code and code:sub(pos, pos) == "[" then
            local equals_count = 0
            local start_pos = pos
            pos = pos + 1
            col = col + 1
            
            while pos <= #code and code:sub(pos, pos) == "=" do
                equals_count = equals_count + 1
                pos = pos + 1
                col = col + 1
            end
            
            if pos <= #code and code:sub(pos, pos) == "[" then
                pos = pos + 1
                col = col + 1
                
                if pos <= #code and (code:sub(pos, pos) == '\n' or code:sub(pos, pos) == '\r') then
                    if code:sub(pos, pos) == '\r' and pos + 1 <= #code and code:sub(pos + 1, pos + 1) == '\n' then
                        pos = pos + 2
                        col = 1
                    else
                        pos = pos + 1
                        col = 1
                    end
                    line = line + 1
                end
                
                local nesting_level = 1
                local nesting_stack = {equals_count}
                
                while pos <= #code do
                    if code:sub(pos, pos) == "]" and pos + 1 <= #code then
                        local close_equals_count = 0
                        local close_pos = pos + 1
                        local close_col = col + 1
                        
                        while close_pos <= #code and code:sub(close_pos, close_pos) == "=" do
                            close_equals_count = close_equals_count + 1
                            close_pos = close_pos + 1
                            close_col = close_col + 1
                        end
                        
                        if close_pos <= #code and code:sub(close_pos, close_pos) == "]" and close_equals_count == nesting_stack[#nesting_stack] then
                            table.remove(nesting_stack)
                            nesting_level = nesting_level - 1
                            
                            if nesting_level == 0 then
                                pos = close_pos + 1
                                col = close_col + 1
                                return pos, line, col, true
                            else
                                pos = close_pos + 1
                                col = close_col + 1
                            end
                        else
                            pos = pos + 1
                            col = col + 1
                        end
                    elseif pos + 1 <= #code and code:sub(pos, pos + 1) == "--" and 
                           pos + 2 <= #code and code:sub(pos + 2, pos + 2) == "[" then
                        local nested_pos = pos + 3
                        local nested_col = col + 3
                        local nested_equals_count = 0
                        
                        while nested_pos <= #code and code:sub(nested_pos, nested_pos) == "=" do
                            nested_equals_count = nested_equals_count + 1
                            nested_pos = nested_pos + 1
                            nested_col = nested_col + 1
                        end
                        
                        if nested_pos <= #code and code:sub(nested_pos, nested_pos) == "[" then
                            nesting_level = nesting_level + 1
                            table.insert(nesting_stack, nested_equals_count)
                            pos = nested_pos + 1
                            col = nested_col + 1
                        else
                            pos = pos + 1
                            col = col + 1
                        end
                    elseif code:sub(pos, pos) == "\n" or code:sub(pos, pos) == "\r" then
                        if code:sub(pos, pos) == "\r" and pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "\n" then
                            pos = pos + 2
                        else
                            pos = pos + 1
                        end
                        line = line + 1
                        col = 1
                    else
                        pos = pos + 1
                        col = col + 1
                    end
                end
                
                return pos, line, col, true
            end
        end
        
        while pos <= #code and code:sub(pos, pos) ~= "\n" and code:sub(pos, pos) ~= "\r" do
            pos = pos + 1
            col = col + 1
        end
        
        return pos, line, col, true
    end
    
    return pos, line, col, false
end

local function read_identifier(code, pos, line, col)
    local start = pos
    local col_start = col
    
    while pos <= #code do
        local c = code:sub(pos, pos)
        if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' then
            pos = pos + 1
            col = col + 1
        else
            break
        end
    end
    
    local identifier = code:sub(start, pos - 1)
    
    if lexer.KEYWORDS[identifier] then
        return pos, line, col, lexer.create_token(lexer.TOKEN_TYPES.KEYWORD, identifier, line, col_start, identifier)
    else
        return pos, line, col, lexer.create_token(lexer.TOKEN_TYPES.IDENTIFIER, identifier, line, col_start, identifier)
    end
end

local function read_number(code, pos, line, col)
    local start = pos
    local col_start = col
    
    if pos + 1 <= #code and code:sub(pos, pos + 1) == "0x" or code:sub(pos, pos + 1) == "0X" then
        pos = pos + 2
        col = col + 2
        
        while pos <= #code do
            local c = code:sub(pos, pos)
            if (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F') then
                pos = pos + 1
                col = col + 1
            else
                break
            end
        end
    else
        while pos <= #code and code:sub(pos, pos) >= '0' and code:sub(pos, pos) <= '9' do
            pos = pos + 1
            col = col + 1
        end
        
        if pos <= #code and code:sub(pos, pos) == '.' then
            pos = pos + 1
            col = col + 1
            
            while pos <= #code and code:sub(pos, pos) >= '0' and code:sub(pos, pos) <= '9' do
                pos = pos + 1
                col = col + 1
            end
        end
        
        if pos <= #code and (code:sub(pos, pos) == 'e' or code:sub(pos, pos) == 'E') then
            pos = pos + 1
            col = col + 1
            
            if pos <= #code and (code:sub(pos, pos) == '+' or code:sub(pos, pos) == '-') then
                pos = pos + 1
                col = col + 1
            end
            
            while pos <= #code and code:sub(pos, pos) >= '0' and code:sub(pos, pos) <= '9' do
                pos = pos + 1
                col = col + 1
            end
        end
    end
    
    local number_str = code:sub(start, pos - 1)
    local number_val = tonumber(number_str)
    
    return pos, line, col, lexer.create_token(lexer.TOKEN_TYPES.NUMBER, number_val, line, col_start, number_str)
end

local function read_string(code, pos, line, col)
    local start = pos
    local col_start = col
    local delimiter = code:sub(pos, pos)
    pos = pos + 1
    col = col + 1
    
    local str = ""
    local raw = delimiter
    
    while pos <= #code do
        local c = code:sub(pos, pos)
        raw = raw .. c
        
        if c == delimiter then
            pos = pos + 1
            col = col + 1
            break
        elseif c == '\\' then
            pos = pos + 1
            col = col + 1
            if pos <= #code then
                c = code:sub(pos, pos)
                raw = raw .. c
                if c == 'n' then
                    str = str .. '\n'
                elseif c == 'r' then
                    str = str .. '\r'
                elseif c == 't' then
                    str = str .. '\t'
                elseif c == 'b' then
                    str = str .. '\b'
                elseif c == 'f' then
                    str = str .. '\f'
                elseif c == '\\' or c == '\'' or c == '\"' then
                    str = str .. c
                else
                    str = str .. c  
                end
                pos = pos + 1
                col = col + 1
            end
        elseif c == '\n' or c == '\r' then
            error("Unterminated string at line " .. line .. ", column " .. col_start)
        else
            str = str .. c
            pos = pos + 1
            col = col + 1
        end
    end
    
    return pos, line, col, lexer.create_token(lexer.TOKEN_TYPES.STRING, str, line, col_start, raw)
end

local function read_long_string(code, pos, line, col, equals_count)
    local start = pos - equals_count - 2 
    local col_start = col - equals_count - 2
    
    pos = pos + 1 
    col = col + 1
    
    local str = ""
    local raw = string.sub(code, start, pos - 1)
    local newlines = 0
    
    if pos <= #code and (code:sub(pos, pos) == '\n' or code:sub(pos, pos) == '\r') then
        if code:sub(pos, pos) == '\r' and pos + 1 <= #code and code:sub(pos + 1, pos + 1) == '\n' then
            raw = raw .. '\r\n'
            pos = pos + 2
            col = 1
        else
            raw = raw .. code:sub(pos, pos)
            pos = pos + 1
            col = 1
        end
        line = line + 1
        newlines = newlines + 1
    end
    
    local found_end = false
    
    while pos <= #code do
        local c = code:sub(pos, pos)
        raw = raw .. c
        
        if c == ']' and pos + equals_count + 1 <= #code then
            local close_pattern = true
            
            for i = 1, equals_count do
                if code:sub(pos + i, pos + i) ~= '=' then
                    close_pattern = false
                    break
                end
            end
            
            if close_pattern and code:sub(pos + equals_count + 1, pos + equals_count + 1) == ']' then
                for i = 1, equals_count do
                    raw = raw .. '='
                end
                raw = raw .. ']'
                pos = pos + equals_count + 2
                col = col + equals_count + 2
                found_end = true
                break
            end
        end
        
        if c == '\n' or c == '\r' then
            if c == '\r' and pos + 1 <= #code and code:sub(pos + 1, pos + 1) == '\n' then
                str = str .. '\n'
                pos = pos + 2
                col = 1
            else
                str = str .. '\n'
                pos = pos + 1
                col = 1
            end
            line = line + 1
            newlines = newlines + 1
        else
            str = str .. c
            pos = pos + 1
            col = col + 1
        end
    end
    
    if not found_end then
        error("Unterminated long string starting at line " .. line - newlines)
    end
    
    return pos, line, col, lexer.create_token(lexer.TOKEN_TYPES.STRING, str, line - newlines, col_start, raw)
end

function lexer.tokenize(code)
    local pos = 1
    local line = 1
    local col = 1
    local tokens = {}
    
    while pos <= #code do
        pos, line, col = skip_whitespace(code, pos, line, col)
        
        if pos > #code then
            break
        end
        
      
        local old_pos = pos
        local old_line = line
        local old_col = col
        pos, line, col, comment_found = process_nested_comments(code, pos, line, col)
        
        if comment_found then
            goto continue
        end
        
        local c = code:sub(pos, pos)
        
       
        if c:match("[%a_]") then
            local start = pos
            local col_start = col
            
            while pos <= #code and code:sub(pos, pos):match("[%a%d_]") do
                pos = pos + 1
                col = col + 1
            end
            
            local id = code:sub(start, pos - 1)
            
            if lexer.KEYWORDS[id] then
                if id == "nil" then
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.NIL, nil, line, col_start, id))
                elseif id == "true" then
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.TRUE, true, line, col_start, id))
                elseif id == "false" then
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.FALSE, false, line, col_start, id))
                else
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.KEYWORD, id, line, col_start, id))
                end
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.IDENTIFIER, id, line, col_start, id))
            end
            
            goto continue
        end
        
        if c:match("[%d]") or (c == "." and pos + 1 <= #code and code:sub(pos + 1, pos + 1):match("[%d]")) then
            local start = pos
            local col_start = col
            local has_decimal = false
            local has_exponent = false
            local is_hex = false
            
            if c == "0" and pos + 1 <= #code and code:sub(pos + 1, pos + 1):lower() == "x" then
                is_hex = true
                pos = pos + 2
                col = col + 2
                
                if pos > #code or not code:sub(pos, pos):match("[%da-fA-F]") then
                    add_error("Malformed hexadecimal number", line, col)
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.NUMBER, 0, line, col_start, code:sub(start, pos - 1)))
                    goto continue
                end
                
                while pos <= #code and code:sub(pos, pos):match("[%da-fA-F]") do
                    pos = pos + 1
                    col = col + 1
                end
            else
                if c == "." then
                    has_decimal = true
                end
                
                while pos <= #code do
                    c = code:sub(pos, pos)
                    
                    if c:match("[%d]") then
                        pos = pos + 1
                        col = col + 1
                    elseif c == "." and not has_decimal then
                        has_decimal = true
                        pos = pos + 1
                        col = col + 1
                    elseif (c == "e" or c == "E") and not has_exponent then
                        if pos + 1 <= #code and (code:sub(pos + 1, pos + 1) == "+" or code:sub(pos + 1, pos + 1) == "-") then
                            pos = pos + 2
                            col = col + 2
                        else
                            pos = pos + 1
                            col = col + 1
                        end
                        
                        has_exponent = true
                        
                        if pos > #code or not code:sub(pos, pos):match("[%d]") then
                            add_error("Malformed number exponent", line, col)
                            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.NUMBER, tonumber(code:sub(start, pos - 1)) or 0, line, col_start, code:sub(start, pos - 1)))
                            goto continue
                        end
                    else
                        break
                    end
                end
            end
            
            local num_str = code:sub(start, pos - 1)
            local num = tonumber(num_str)
            
            if not num then
                add_error("Malformed number", line, col)
                num = 0
            end
            
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.NUMBER, num, line, col_start, num_str))
            
            goto continue
        end
        
        if c == "'" or c == '"' then
            local quote = c
            local start = pos
            local col_start = col
            pos = pos + 1
            col = col + 1
            
            local str = ""
            local raw = quote
            
            while pos <= #code do
                c = code:sub(pos, pos)
                raw = raw .. c
                
                if c == quote then
                    pos = pos + 1
                    col = col + 1
                    break
                elseif c == "\\" then
                    pos = pos + 1
                    col = col + 1
                    
                    if pos > #code then
                        add_error("Unterminated string", line, col)
                        break
                    end
                    
                    c = code:sub(pos, pos)
                    raw = raw .. c
                    
                    if c == "a" then
                        str = str .. "\a"
                    elseif c == "b" then
                        str = str .. "\b"
                    elseif c == "f" then
                        str = str .. "\f"
                    elseif c == "n" then
                        str = str .. "\n"
                    elseif c == "r" then
                        str = str .. "\r"
                    elseif c == "t" then
                        str = str .. "\t"
                    elseif c == "v" then
                        str = str .. "\v"
                    elseif c == "\\" then
                        str = str .. "\\"
                    elseif c == "'" then
                        str = str .. "'"
                    elseif c == '"' then
                        str = str .. '"'
                    elseif c:match("[%d]") then
                        local digits = c
                        
                        for i = 1, 2 do
                            if pos + i <= #code and code:sub(pos + i, pos + i):match("[%d]") then
                                digits = digits .. code:sub(pos + i, pos + i)
                                raw = raw .. code:sub(pos + i, pos + i)
                            else
                                break
                            end
                        end
                        
                        local byte = tonumber(digits)
                        if byte and byte <= 255 then
                            str = str .. string.char(byte)
                            pos = pos + #digits - 1
                            col = col + #digits - 1
                        else
                            str = str .. c
                        end
                    elseif c == "z" then
                        pos = pos + 1
                        col = col + 1
                        
                        while pos <= #code and code:sub(pos, pos):match("[%s]") do
                            raw = raw .. code:sub(pos, pos)
                            
                            if code:sub(pos, pos) == "\n" or code:sub(pos, pos) == "\r" then
                                if code:sub(pos, pos) == "\r" and pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "\n" then
                                    raw = raw .. code:sub(pos + 1, pos + 1)
                                    pos = pos + 2
                                else
                                    pos = pos + 1
                                end
                                
                                line = line + 1
                                col = 1
                            else
                                pos = pos + 1
                                col = col + 1
                            end
                        end
                        
                        pos = pos - 1
                        col = col - 1
                    else
                        str = str .. c
                    end
                    
                    pos = pos + 1
                    col = col + 1
                elseif c == "\n" or c == "\r" then
                    add_error("Unterminated string", line, col)
                    break
                else
                    str = str .. c
                    pos = pos + 1
                    col = col + 1
                end
            end
            
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.STRING, str, line, col_start, raw))
            
            goto continue
        end
        
        if c == "[" and pos + 1 <= #code and (code:sub(pos + 1, pos + 1) == "[" or code:sub(pos + 1, pos + 1) == "=") then
            local equals_count = 0
            local start_pos = pos
            pos = pos + 1
            col = col + 1
            
            while pos <= #code and code:sub(pos, pos) == "=" do
                equals_count = equals_count + 1
                pos = pos + 1
                col = col + 1
            end
            
            if pos <= #code and code:sub(pos, pos) == "[" then
                pos, line, col, token = read_long_string(code, pos, line, col, equals_count)
                table.insert(tokens, token)
                goto continue
            else
                pos = start_pos
                col = col_start
            end
        end
        
        if c == "+" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.ADD, "+", line, col, "+"))
            pos = pos + 1
            col = col + 1
        elseif c == "-" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.SUB, "-", line, col, "-"))
            pos = pos + 1
            col = col + 1
        elseif c == "*" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.MUL, "*", line, col, "*"))
            pos = pos + 1
            col = col + 1
        elseif c == "/" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "/" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.IDIV, "//", line, col, "//"))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.DIV, "/", line, col, "/"))
                pos = pos + 1
                col = col + 1
            end
        elseif c == "%" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.MOD, "%", line, col, "%"))
            pos = pos + 1
            col = col + 1
        elseif c == "^" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.POW, "^", line, col, "^"))
            pos = pos + 1
            col = col + 1
        elseif c == "#" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LEN, "#", line, col, "#"))
            pos = pos + 1
            col = col + 1
        elseif c == "&" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.BAND, "&", line, col, "&"))
            pos = pos + 1
            col = col + 1
        elseif c == "|" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.BOR, "|", line, col, "|"))
            pos = pos + 1
            col = col + 1
        elseif c == "~" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.NE, "~=", line, col, "~="))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.BXOR, "~", line, col, "~"))
                pos = pos + 1
                col = col + 1
            end
        elseif c == "<" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LE, "<=", line, col, "<="))
                pos = pos + 2
                col = col + 2
            elseif pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "<" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.SHL, "<<", line, col, "<<"))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LT, "<", line, col, "<"))
                pos = pos + 1
                col = col + 1
            end
        elseif c == ">" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.GE, ">=", line, col, ">="))
                pos = pos + 2
                col = col + 2
            elseif pos + 1 <= #code and code:sub(pos + 1, pos + 1) == ">" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.SHR, ">>", line, col, ">>"))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.GT, ">", line, col, ">"))
                pos = pos + 1
                col = col + 1
            end
        elseif c == "=" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "=" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.EQ, "==", line, col, "=="))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.ASSIGN, "=", line, col, "="))
                pos = pos + 1
                col = col + 1
            end
        elseif c == "(" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LPAREN, "(", line, col, "("))
            pos = pos + 1
            col = col + 1
        elseif c == ")" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.RPAREN, ")", line, col, ")"))
            pos = pos + 1
            col = col + 1
        elseif c == "[" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LBRACKET, "[", line, col, "["))
            pos = pos + 1
            col = col + 1
        elseif c == "]" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.RBRACKET, "]", line, col, "]"))
            pos = pos + 1
            col = col + 1
        elseif c == "{" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.LBRACE, "{", line, col, "{"))
            pos = pos + 1
            col = col + 1
        elseif c == "}" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.RBRACE, "}", line, col, "}"))
            pos = pos + 1
            col = col + 1
        elseif c == "," then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.COMMA, ",", line, col, ","))
            pos = pos + 1
            col = col + 1
        elseif c == ";" then
            table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.SEMI, ";", line, col, ";"))
            pos = pos + 1
            col = col + 1
        elseif c == ":" then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == ":" then
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.DOUBLE_COLON, "::", line, col, "::"))
                pos = pos + 2
                col = col + 2
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.COLON, ":", line, col, ":"))
                pos = pos + 1
                col = col + 1
            end
        elseif c == "." then
            if pos + 1 <= #code and code:sub(pos + 1, pos + 1) == "." then
                if pos + 2 <= #code and code:sub(pos + 2, pos + 2) == "." then
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.VARARG, "...", line, col, "..."))
                    pos = pos + 3
                    col = col + 3
                else
                    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.CONCAT, "..", line, col, ".."))
                    pos = pos + 2
                    col = col + 2
                end
            else
                table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.DOT, ".", line, col, "."))
                pos = pos + 1
                col = col + 1
            end
        else
            
            add_error("Unrecognized character: " .. c, line, col)
            pos = pos + 1
            col = col + 1
        end
        
        ::continue::
    end
    
    table.insert(tokens, lexer.create_token(lexer.TOKEN_TYPES.EOF, "", line, col, ""))
    
    return tokens
end

return lexer
