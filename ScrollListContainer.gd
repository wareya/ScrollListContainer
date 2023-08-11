tool
class_name ScrollListContainer
extends Container

var scrollbar_v : VScrollBar
var scrollbar_h : HScrollBar
var dummy : Node2D
var bg_node : NinePatchRect

func check_scrollbars():
    if scrollbar_v == null:
        scrollbar_v = VScrollBar.new()
        scrollbar_v.name = "_scrollbar_v"
        VisualServer.canvas_item_set_z_index(scrollbar_v.get_canvas_item(), 1)
        add_child(scrollbar_v)
    if scrollbar_h == null:
        scrollbar_h = HScrollBar.new()
        scrollbar_h.name = "_scrollbar_h"
        VisualServer.canvas_item_set_z_index(scrollbar_h.get_canvas_item(), 1)
        add_child(scrollbar_h)

func _init():
    set_notify_transform(true)
    check_scrollbars()
    
    dummy = Node2D.new()
    bg_node = NinePatchRect.new()
    bg_node.show_behind_parent = true
    bg_node.name = "_background"
    dummy.add_child(bg_node)
    dummy.name = "_background_holder"
    add_child(dummy)
    
    var _unused = scrollbar_h.connect("value_changed", self, "_scroll")
    _unused = scrollbar_v.connect("value_changed", self, "_scroll")
    _unused = connect("sort_children", self, "_reflow")
    
    set_clip_contents(true)

func _ready():
    var _unused = get_viewport().connect("gui_focus_changed", self, "check_focus")
    bg_update()

var _bg_extra_size = Vector2()
func bg_update():
    if !bg_node or !is_instance_valid(bg_node):
        return
    
    bg_node.texture = background_texture
    if bg_node.texture:
        var tex_size : Vector2 = bg_node.texture.get_size()
        bg_node.patch_margin_left = int(background_inner_rect.position.x)
        bg_node.patch_margin_top = int(background_inner_rect.position.y)
        bg_node.patch_margin_right = int(tex_size.x - background_inner_rect.end.x)
        bg_node.patch_margin_bottom = int(tex_size.y - background_inner_rect.end.y)
        bg_node.rect_position = Vector2(-bg_node.patch_margin_left, -bg_node.patch_margin_top)
        _bg_extra_size = Vector2()
        _bg_extra_size.x = bg_node.patch_margin_left + bg_node.patch_margin_right
        _bg_extra_size.y = bg_node.patch_margin_top + bg_node.patch_margin_bottom
        bg_node.rect_size = rect_size + _bg_extra_size

enum ALIGN {
    ALIGN_START,
    ALIGN_MIDDLE,
    ALIGN_END,
}

export var vertical : bool = true setget set_vertical
export var follow_focus : bool = true setget set_follow_focus

export var background_texture : Texture = null setget set_bg
export var background_inner_rect : Rect2 = Rect2() setget set_bg_rect

func set_bg(_background_texture):
    background_texture = _background_texture
    bg_update()
    update()

func set_bg_rect(_background_inner_rect):
    background_inner_rect = _background_inner_rect
    bg_update()
    update()

func set_follow_focus(_follow_focus):
    follow_focus = _follow_focus
    queue_sort()
    update()

func set_vertical(_vertical):
    vertical = _vertical
    queue_sort()
    update()

var scroll_offset : Vector2 = Vector2()
func _scroll(_unused):
    if !vertical:
        scroll_offset.x = scrollbar_h.value
    else:
        scroll_offset.y = scrollbar_v.value
    queue_sort()
    update()

func check_focus(focus_owner : Control):
    if !follow_focus:
        return
    if !focus_owner or !is_instance_valid(focus_owner) or !is_a_parent_of(focus_owner):
        return
    var xform = get_global_transform().inverse()
    var focus_rect : Rect2 = xform.xform(focus_owner.get_global_rect())
    var rect : Rect2 = get_rect()
    if vertical:
        if focus_rect.end.y > rect.end.y:
            scrollbar_v.value += focus_rect.end.y - rect.end.y
        elif focus_rect.position.y < rect.position.y:
            scrollbar_v.value += focus_rect.position.y - rect.position.y
    else:
        if focus_rect.end.x > rect.end.x:
            scrollbar_h.value += focus_rect.end.x - rect.end.x
        elif focus_rect.position.x < rect.position.x:
            scrollbar_h.value += focus_rect.position.x - rect.position.x

func fix_bg():
    if dummy and is_instance_valid(dummy) and bg_node and is_instance_valid(bg_node) and background_texture != null:
        var p : Node = dummy.get_parent()
        var p2 : Node = get_parent()
        p.remove_child(dummy)
        p2.add_child_below_node(self, dummy)
        p2.move_child(dummy, dummy.get_index()-1)
        dummy.global_transform = get_global_transform()
        bg_node.rect_position.x = -bg_node.patch_margin_left
        bg_node.rect_position.y = -bg_node.patch_margin_top
        bg_node.rect_size = rect_size + _bg_extra_size
    dummy.visible = false

func _notification(what):
    if what in [NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED]:
        fix_bg()
        fix_virtual_bg()
    if what == NOTIFICATION_PREDELETE:
        VisualServer.free_rid(_sibling_ci_rid)
        _sibling_ci_rid = null

var _sibling_ci_rid = null

func get_parent_canvasitem_of(node : CanvasItem) -> CanvasItem:
    if node is Control:
        var r = node.get_parent_control()
        if r:
            return r
    var p = node.get_parent()
    if p and p is CanvasItem:
        return p
    elif p:
        return get_parent_canvasitem_of(p)
    else:
        return null

func fix_virtual_bg():
    if _sibling_ci_rid == null:
        _sibling_ci_rid = VisualServer.canvas_item_create()
    
    var rid = _sibling_ci_rid
    VisualServer.canvas_item_clear(rid)
    var p = get_parent_canvasitem_of(self)
    
    var parent_rid = get_canvas()
    if p:
        parent_rid = p.get_canvas_item()
    
    VisualServer.canvas_item_set_parent(rid, parent_rid)
    # fix ordering
    VisualServer.canvas_item_set_parent(get_canvas_item(), parent_rid)
    
    VisualServer.canvas_item_set_transform(rid, dummy.transform)
    
    var t = bg_node.texture
    var s = Rect2(Vector2(), t.get_size())
    VisualServer.canvas_item_add_nine_patch(rid, bg_node.get_rect(), s, t, background_inner_rect.position, background_inner_rect.end, bg_node.axis_stretch_horizontal, bg_node.axis_stretch_vertical, bg_node.draw_center, bg_node.modulate)

func _reflow():
    check_scrollbars()
    
    var cursor : Vector2 = Vector2()
    var rect : Rect2 = get_rect()
    rect.position = Vector2()
    
    if vertical:
        scroll_offset.x = 0
        var scroll_size = scrollbar_v.get_combined_minimum_size().x
        scrollbar_h.hide()
        scrollbar_v.show()
        fit_child_in_rect(scrollbar_v, Rect2(rect.size.x - scroll_size, 0, scroll_size, rect.size.y))
        rect.size.x -= scroll_size
    else:
        scroll_offset.y = 0
        var scroll_size = scrollbar_h.get_combined_minimum_size().y
        scrollbar_v.hide()
        scrollbar_h.show()
        fit_child_in_rect(scrollbar_h, Rect2(0, rect.size.y - scroll_size, rect.size.x, scroll_size))
        rect.size.y -= scroll_size
    
    var remain_size_part = Vector2(rect.size.x, 0.0) if vertical else Vector2(0.0, rect.size.y)
    
    for _child in get_children():
        if _child == scrollbar_v or _child == scrollbar_h or _child.is_set_as_toplevel() or !_child.is_visible_in_tree():
            continue
        if _child is Control:
            var child : Control = _child
            var ms = child.get_combined_minimum_size()
            var remain_ms_part = ms * (Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0))
            var remaining = Rect2(rect.position + cursor, remain_size_part + remain_ms_part)
            fit_child_in_rect(child, remaining)
            if vertical:
                cursor.y = child.get_rect().end.y
            else:
                cursor.x = child.get_rect().end.x
            child.rect_position -= scroll_offset
        elif _child is Node2D:
            var child : Node2D = _child
            child.position = cursor
            child.position -= scroll_offset
    
    if vertical:
        scrollbar_v.max_value = max(rect.size.y, cursor.y)
        scrollbar_v.page = rect.size.y
    else:
        scrollbar_h.max_value = max(rect.size.x, cursor.x)
        scrollbar_h.page = rect.size.x
