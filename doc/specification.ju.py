# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %% [md]
"""
# Neopyter specifications
> The source of this notebook is `doc/specification.ju.py`

This is a example file describe the specification of `.ju.py`. We will introduce some specifications and notices you need to learn.

The main format supported  is the [percent](https://jupytext.readthedocs.io/en/latest/formats-scripts.html) format: cells can have

* title
* a cell type (`code`, `markdown`, `md` or `raw`, omitted for code cells)
* and cell metadata

Here is a example of cell separator(the percent format)
```python
 # %% Optional title [cell type] key="value"
```
"""

# %% [md]
"""
## Code Cell
These are all legitimate code cells:
* Default cell separtor
```python
 # %%
```
* Cell separtor with title

```python
 # %% title
```
E.g.
"""

# %% import some module

import time


# %%
def say(msg):
    print(msg)


# %% [md]
"""
### Cell Magic
`Cell magic` is not a standard  of percent format, but for convenience, we support multiple formats
<table width="90%">
<tr>
<td> Code </td> <td> Notebook </td>  <td> Description </td>
</tr>
<tr>
<td>

```python
# %%
# %%js
'''
console.log("Hello")
console.log("Neopyter")
'''
```

</td>
<td>

![](./cell_magic_js.png)

</td>

<td>
If the cell contains only one string, we extract the string as the content of the cell
</td>
</tr>
<tr>
<td> 

```python
# %%
# %%js
# console.log("Hello")
# console.log("Neopyter")
```

</td>
<td>

![](./cell_magic_js.png)

</td>
<td>
If the cell contains only multiple comments, and all comments are start with `# `, we extract the comment as cell content.
</td>
</tr>
<tr>
<td> 

```python
# %%
# %%time
a = 1 + 2
time.sleep(1)
```

</td>
<td>

![](./cell_magic_time.png)

</td>
<td>
Otherwise, we keep it as cell content.
</td>
</tr>
<td> 
</table>
"""

# %%
# %%js
"""
console.log('Hello')
console.log("Neopyter")
"""
# %%
# %%js
# console.log('Hello')
# console.log("Neopyter")


# %%
# %%time
time.sleep(1)

# %% [md]
"""
### Line Magic
We support line magic, you can write line magic with prefix `# `, e.g.
```python
# %time time.sleep(1)
```
"""
# %%
# %time time.sleep(1)

# %% [md]
"""
## Markdown Cell
Neopyter support markdown cell to, `md` will be treated as `markdown`. We support multiple formats too.
<table width="90%">
<tr>
<td> Code </td> <td> Notebook </td>  <td> Description </td>
</tr>
<tr>
<td>

```python
# %% [md]
'''
### Heading

- list item 1
- list item 2
'''
```

</td>
<td>

![](./markdown_cell.png)

</td>

<td>
If the cell contains only one string, we extract the string as the content of the cell
</td>
</tr>
<tr>
<td> 

```python
# %% [markdown]
# ### Heading

# - list item 1
# - list item 2
```

</td>
<td>

![](./markdown_cell.png)

</td>
<td>
If the cell contains only multiple comments, and all comments are start with `# `, we extract the comment as cell content.
</td>
</tr>
<tr>
<td> 

```python
# %% [markdown]
### Heading

print("Hello")

```

</td>
<td>

![](./markdown_cell_simple.png)

</td>
<td>
Otherwise, we keep it as cell content. Although this may cause some problems
</td>
</tr>
<td> 
</table>
"""

# %% [md]
"""
### Heading

- list item 1
- list item 2
"""

# %% [markdown]
# ### Heading

# - list item 1
# - list item 2

# %% [markdown]
### Heading

print("Hello")

# %% [md]
"""
## Raw Cell
Raw cell fellow the same standard with markdown
"""
