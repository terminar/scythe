# String
```lua
local String = require(public.string)
```
This module overrides the `string` type's metatable so that its methods can
be called on strings via `:` syntax. This is done when the module is loaded,
so it simply has to be required for all strings in the current scope to benefit.

<section class="segment">

### String.split(s[, separator]) :id=string-split

Splits a string at each occurrence of a given separator

| **Required** | []() | []() |
| --- | --- | --- |
| s | string |  |

| **Optional** | []() | []() |
| --- | --- | --- |
| separator | string | Any number of characters (_not_ a standard Lua pattern). <br> - Separators are not included in the split strings - Sequential occurrences of the separator are split as empty strings <br> If no pattern is given, splits at every character |

| **Returns** | []() |
| --- | --- |
| array | A list of split strings |

</section>
<section class="segment">

### String.splitLines(s) :id=string-splitlines

Splits a string at each new line

| **Required** | []() | []() |
| --- | --- | --- |
| s | string |  |

| **Returns** | []() |
| --- | --- |
| array | A list of split strings |

</section>

----
_This file was automatically generated by Scythe's Doc Parser._
