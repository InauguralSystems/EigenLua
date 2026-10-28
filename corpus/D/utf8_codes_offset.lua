-- surface: utf8 codes strict and lax iteration, invalid sequences, and offset boundary and continuation-byte behavior
local function show(label, f, ...)
  local r = table.pack(pcall(f, ...))
  io.write(label)
  for i = 1, r.n do io.write("\t", tostring(r[i])) end
  io.write("\n")
end

local function codes(s, lax)
  local out = {}
  for p, c in utf8.codes(s, lax) do
    out[#out + 1] = p .. ":" .. c
  end
  return table.concat(out, ",")
end

local valid = "A\xc3\xa9\xe2\x82\xac\xf0\x9f\x98\x80Z"
show("codes valid", codes, valid)
show("codes continuation", codes, "A\x80B")
show("codes truncated", codes, "A\xe2\x82")
show("codes overlong strict", codes, "\xc0\x80")
show("codes out-of-range strict", codes, "\xf4\x90\x80\x80")
show("codes out-of-range lax", codes, "\xf4\x90\x80\x80", true)
show("codes extended lax", codes, "\xf8\x88\x80\x80\x80", true)

show("offset forward", utf8.offset, valid, 1, 1)
show("offset negative n", utf8.offset, valid, -1, #valid + 1)
show("offset zero lead", utf8.offset, valid, 0, 6)
show("offset zero continuation", utf8.offset, valid, 0, 7)
show("offset continuation start", utf8.offset, valid, 1, 3)
show("offset i zero", utf8.offset, valid, 1, 0)
show("offset i negative", utf8.offset, valid, 1, -1)
show("offset i past end", utf8.offset, valid, 1, #valid + 2)
show("offset n past end", utf8.offset, valid, 20, 1)
show("offset negative past start", utf8.offset, valid, -20, #valid + 1)
