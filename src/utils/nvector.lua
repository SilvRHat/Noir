-- Utility script to extend arithmetic towards tables for arbitrary vectors and matrices

local VectorN

local ARITH_FUNCS = {
    add = function (a,b) return a+b end;
    sub = function (a,b) return a-b end;
    mul = function (a,b) return a*b end;
    div = function (a,b) return a/b end;
    mod = function (a,b) return a%b end;
    pow = function (a,b) return a^b end;
}

local VALUE_FROM_TYPE_AND_INDEX_FUNCS = {
    table = function(a,k) return a[k] or 0 end;
    Vector3 = function(a,k) return table.find({'X','Y','Z'},k) and a[k] or 0 end;
    Vector2 = function(a,k) return table.find({'X','Y'},k) and a[k] or 0 end;
    number = function(a,k) return a end;
}

function valueGivenKey(a, k)
    return VALUE_FROM_TYPE_AND_INDEX_FUNCS[typeof(a)](a,k) end

function performArithmetic(arith, a, b)
    local args = {a, b}
    local res = VectorN.new()
    local types = {}
    types[typeof(b)] = 2; types[typeof(a)] = 1;

    if types['table'] then
        for k, v in pairs(args[types['table']]) do
            res[k] = performArithmetic(arith,
                valueGivenKey(a, k), 
                valueGivenKey(b, k)
            )
        end
    elseif types['Vector3'] then
        res = Vector3.new()
        for _, axis in pairs({'X','Y','Z'}) do
            res += Vector3.fromAxis(axis) * performArithmetic(arith,
                valueGivenKey(a, axis), 
                valueGivenKey(b, axis)
            )
        end
    elseif types['Vector2'] then
        res = Vector2.new()
        for _, axis in pairs({'X','Y'}) do
            local axv3 = Vector3.fromAxis(axis)
            res += Vector2.new(axv3.X, axv3.Y) * performArithmetic(arith,
                valueGivenKey(a, axis), 
                valueGivenKey(b, axis)
            )
        end
    else
        res = ARITH_FUNCS[arith](a,b) end
        
    return res
end


VectorN = {
    ClassName = 'VectorN';
    __add = function(...) 
        return performArithmetic('add', ...) end;
    __sub = function(...) 
        return performArithmetic('sub', ...) end;
    __mul = function(...) 
        return performArithmetic('mul', ...) end;
    __div = function(...) 
        return performArithmetic('div', ...) end;
    __pow = function(...) 
        return performArithmetic('pow', ...) end;
    __mod = function(...) 
        return performArithmetic('mod', ...) end;
}

function VectorN.new(...)
    local t={...}
    
    return setmetatable(t, VectorN)
end

return VectorN