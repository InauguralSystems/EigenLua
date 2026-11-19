-- surface: number printing, formatting, parsing, and lexing
local vals = {
{"maxi",math.maxinteger},{"mini",math.mininteger},{"2^53+1",(2^53|0)+1},{"-(2^53+1)",-((2^53|0)+1)},
{"2^53i",2^53|0},{"2^53-1i",(2^53|0)-1},{"-(2^53-1)i",1-(2^53|0)},{"-2^53i",-(2^53|0)},
{"2^62i",1<<62},{"maxi-1",math.maxinteger-1},{"mini+1",math.mininteger+1},{"0",0},{"-1",-1},
{"1.0",1.0},{"-0.0",-0.0},{"1e15",1e15},{"1e16",1e16},{"2^53",2^53},{"2^63",2^63},{"-2^63",-2^63},
{"0.1+0.2",0.1+0.2},{"inf",math.huge},{"-inf",-math.huge},{"nan",0/0},{"-nan",-(0/0)},
{"1e19",1e19},{"1e100",1e100},{"1.5e300",1.5e300},{"9.3e18",9.3e18},{"-9.3e18",-9.3e18},
{"2^63-1024",2^63-1024},{"2^64",2^64},{"1e308",1e308},{"5e-324",5e-324},{"123.456",123.456},
{"-1e15",-1e15},{"1e14+0.5",1e14+0.5},{"3.0",3.0},{"-3.0",-3.0},{"100.0",100.0}}
local fmts={"%d","%s","%g","%.14g","%a","%5.2f","%x","%i","%.3f","%e"}
for _,p in ipairs(vals) do local name,v=p[1],p[2]; print(name,"print:",v); print(name,"tostring:",tostring(v),"concat:",v.."","type:",math.type(v)); for _,f in ipairs(fmts) do local ok,s=pcall(string.format,f,v); print(name,f,ok,s) end end
local strs={"0x1p4","0x.8p1","0xA.8p0","0x1P-2","0x1p","0xp1","0x.p1","0x1.8","0x","0x1pz","0x1p+","0X1P4","9223372036854775807","9223372036854775808","-9223372036854775808","-9223372036854775809","18446744073709551616","0x7fffffffffffffff","0x8000000000000000","0xffffffffffffffff","0x10000000000000000","0x1ffffffffffffffff","-0x1","-0x8000000000000000","1e400","-1e400","0x123456789abcdef0123p0","0x123456789abcdef0123","  0x10  ","1e","1.",".5","inf","nan","0x1.fffffffffffffp1023","0x1p-1074","0x1p1024"}
for _,s in ipairs(strs) do
 local ok,v=pcall(tonumber,s); if ok then print("tonumber",s,math.type(v),v) else print("tonumber",s,"ERR",v) end
 local lok,f=pcall(load,"return "..s); if lok and f then local ok2,r=pcall(f); print("lex",s,ok2,math.type(r),r) elseif lok then print("lex",s,"nocompile") else print("lex",s,false,f) end
end
local bok,bv=pcall(function() return tonumber("10",16),tonumber("ff",16),tonumber("zz",36),tonumber("7fffffffffffffff",16),tonumber("8000000000000000",16),tonumber("-ff",16) end); if bok then print(bv,select(2,pcall(function() return tonumber("10",16),tonumber("ff",16),tonumber("zz",36),tonumber("7fffffffffffffff",16),tonumber("8000000000000000",16),tonumber("-ff",16) end))) else print("tonumber-base",false,bv) end
