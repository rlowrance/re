-- parse key and value from input record
-- ARGS:
-- s : string, the input record
-- 
-- RETURNS:
-- key   : string, bytes in s up to but not including the first tab (\t)
-- value : string, bytes in s after the tab (\t); potentially empty
function getKeyValue(s)
    local key, value = string.match(s, '^(.*)\t(.*)$')
    if key == nil then
        return s, nil
    end
    return key, value
end
