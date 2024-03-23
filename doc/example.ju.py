# This is example for neopyter notebook format
# This will become first cell
print("I am first cell")

# %%
print("previous line is standard cell separator")

# %% Cell with title
print("previous line is standard cell separator, can include a title `Cell with title`")

# %% [md]
"""
```lua

print("you can mark cell tyep with `[lang]` syntax, notice the space")
print("default cell type is [code]")
```
"""
# %% ------------------------parse as code cell---------------------------------------
# %%

# %% 

# %% title

# next line is line magic in jupyter lab
# %sleep 

# %% [title

# %% []

# %% [ ]


# %% [code] title

# %% ------------------------parse as magic cell---------------------------------------

# %%timeit

# %%timeit
"""
print("Hello")
"""



# %% ------------------------parse as markdown cell---------------------------------------

# %% [md]
"""
# this is first level
## this is second level

```bash
$ echo $PATH
```
"""

# %% [markdown] 

# %% [md] title

# %% [markdown] title

# %% ------------------------parse as raw cell---------------------------------------

# %% [raw] 
"""
this is raw cell content
"""

# %% [raw] title

# %% ------------------------parse as special cell---------------------------------------


# %% [sql]

# %% [sql] title

# %% [js]

# %% [js] title

# %% ------------------------parse as special cell---------------------------------------
# %%

# %%timeit


