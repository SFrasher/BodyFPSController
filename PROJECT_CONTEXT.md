# Godot 4.6 IK Project - Context Reference

## Project Overview
- **Name:** Godot 4.6 New Ik Aim
- **Engine:** Godot 4.6.2 (forward_plus renderer)
- **Source:** Brok3ncircuit Patreon project
- **Current Design:** Third-person weapon aiming system with IK

## Key Stats
- **Skeleton:** 68 bones (full-body: head, spine, shoulders, arms, hands, fingers, legs)
- **Scripts:** 4 core GDScript files (~418 lines total)
- **Scenes:** 2 main scenes (main.tscn, Player.tscn)
- **Total files:** 26 files

## Scene Structure
```
Main (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── Floor (CSGBox3D)
├── AudioStreamPlayer
└── Player (CharacterBody3D) [instanced from Player.tscn]
    ├── Model/GeneralSkeleton (68 bones)
    ├── AnimationPlayer
    ├── AnimationTree (strafe controller)
    ├── BoneAttachment3D (IK pole target)
    ├── TargetPivot (weapon aiming targets)
    ├── Camera (third-person follow)
    └── CollisionShape3D (capsule)
```

## Core Scripts
| File | Lines | Purpose |
|------|-------|---------|
| `Player.gd` | 137 | Movement, root motion, strafe/TIP logic |
| `NewTPSCamera.gd` | 118 | Third-person camera with SpringArm3D |
| `motorica_strafe_controller.gd` | ~4000 | Animation blend tree controller |
| `Exit.gd` | ~1000 | Scene exit/menu logic |

## IK System Details
- **CCDIK3D:** Spine→Head chain (5 joints) for procedural aiming
- **TwoBoneIK3D:** Left/Right arms with pole targets (LHPoleTarget, etc.)
- **CopyTransformModifiers:** 4× for weapon grip sync
- **Aiming targets:** RHWeaponTarget, RHUpperArmWeaponTarget, SpineTargetWeaponAim

## Animation System
- **AnimationTree:** 8-directional strafe blending (WALK blend space)
- **Turn-in-Place (TIP):** Root-locked idle rotation (currently enabled)
- **Root Motion:** Enabled, drives locomotion from animation

## Camera System (Third-Person)
```gdscript
@export var spring_arm: SpringArm3D       # Distance from player
@export var camera_target: Node3D         # Rotation target
@export var follow_target: Node3D         # Position target
spring_arm.spring_length = -2.3           # Default follow distance
follow_target_height_offset = 1.27        # Eye height
```
- Yaw/pitch input mapped to camera_target, not head bone
- Aiming adjusts spring arm length & position

## Physics
- **Body:** CharacterBody3D with capsule collision
- **Gravity:** 9.8 m/s²
- **No ragdoll system**

## Current Exported Properties
```gdscript
# Player.gd
@export var animation_tree: AnimationTree
@export var camera_target: Node3D
@export var enable_tip: bool = true

# NewTPSCamera.gd
@export var target_pivot: Marker3D
@export var follow_target: Node3D
@export var spring_arm: SpringArm3D
@export var follow_target_height_offset = 1.27
@export var pitch_max = 80
@export var pitch_min = -60
@export var normal_spring_arm = -2.3
@export var aim_spring_arm = -0.5
```

## Input Mapping (Expected)
- **Movement:** right/left/forward/backward (WASD)
- **Camera:** mouse motion (yaw/pitch), gamepad analog sticks (lookleft/lookright/lookup/lookdown)
- **Aiming:** aim input (transitions camera/spring arm)

## For FPS Conversion
**Keep:** Skeleton, IK system, bone attachments, physics collision, MCP addon

**Replace:** Camera system, animations, movement controller, aiming logic

**Estimated effort:** 45-80 hours

**See:** FIRSTPERSON_ANALYSIS.md for detailed breakdown
