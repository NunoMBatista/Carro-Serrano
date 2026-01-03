# PathMesh3D Railing Fix Guide

## Problem
The PathMesh3D nodes in terrain files show `triangle_count = 0` even though:
- A mesh is assigned (baby.obj)
- A Path3D child exists with a valid curve (86 points)
- This worked in earlier versions of the game

## Root Cause
The `PathMesh3D` nodes are missing the `path_3d` property that links them to their child `Path3D` node.

According to the PathMesh3D documentation:
> Simply add the PathMesh3D node to the scene, **set its `path_3d` property to a Path3D node**, and set its mesh property to any Mesh derived resource.

## Current Structure (Broken)
```
[node name="PathMesh3D" type="PathMesh3D" parent="Terrain"]
mesh = ExtResource("16_hgkgj")  # ✓ Mesh is set
# ✗ MISSING: path_3d property
surface_0/triangle_count = 0    # ✗ No triangles generated

[node name="Path3D" type="Path3D" parent="Terrain/PathMesh3D"]
curve = SubResource("Curve3D_a0mms")  # ✓ Curve has 86 points
```

## Solution
You need to set the `path_3d` property in the Godot editor for each PathMesh3D node.

### Steps to Fix (In Godot Editor):

1. **Open the terrain scene** (e.g., `terrain_1.tscn`, `terrain_2.tscn`, `terrain_3.tscn`)

2. **Select the PathMesh3D node** in the scene tree

3. **In the Inspector panel**, find the `Path 3D` property (should be near the top)

4. **Click the dropdown** next to "Path 3D" and select the child `Path3D` node
   - Or drag the Path3D node from the scene tree into the property field

5. **The mesh should immediately generate** - you'll see:
   - `triangle_count` change from 0 to a positive number
   - The railing mesh appear along the path in the viewport

6. **Save the scene**

7. **Repeat for all terrain files** that have PathMesh3D:
   - `scenes/terrain_1.tscn`
   - `scenes/terrain_2.tscn`
   - `scenes/terrain_3.tscn`
   - `scenes/terrain/terrain_1.tscn` (if exists)

### Expected Result After Fix:
```
[node name="PathMesh3D" type="PathMesh3D" parent="Terrain"]
mesh = ExtResource("16_hgkgj")
path_3d = NodePath("Path3D")  # ✓ ADDED: Links to child Path3D
surface_0/triangle_count = 1234  # ✓ Triangles generated!

[node name="Path3D" type="Path3D" parent="Terrain/PathMesh3D"]
curve = SubResource("Curve3D_a0mms")
```

## Why This Happened
This likely broke because:
- Godot version update changed how PathMesh3D properties are saved
- The PathMesh3D addon was updated and requires explicit path_3d property
- Scene files were modified and the property was lost

## Files to Fix

### terrain_1.tscn
- PathMesh3D at line 1781 → link to Path3D at line 1875

### terrain_2.tscn
- PathMesh3D at line 450 → link to Path3D at line 463

### terrain_3.tscn
- PathMesh3D at line 408 → link to Path3D at line 439

### scenes/terrain/terrain_1.tscn
- PathMesh3D at line 484 → link to Path3D at line 515

## Additional PathMesh3D Settings
Once the path is linked, you can customize the railing appearance:

- **Distribution**: How meshes are spaced (0 = edge to edge, 1 = spaced by mesh size)
- **Alignment**: How meshes align to the path (0 = top, 1 = center, 2 = bottom)
- **Warp Along Curve**: Whether meshes bend with the curve
- **Tilt**: Whether meshes tilt with the path
- **Offset**: X/Y offset from the path

## Testing
After fixing:
1. Open `main_scene.tscn`
2. Run the game
3. You should see railings along the road
4. Check that triangle_count > 0 in the Inspector

## Alternative: Script-Based Fix
If you prefer to fix this programmatically, you can add a script that runs in `_ready()`:

```gdscript
# Attach to PathMesh3D node
extends PathMesh3D

func _ready():
    # Find child Path3D and link it
    for child in get_children():
        if child is Path3D:
            path_3d = child
            break
```

But the editor fix is cleaner and permanent.