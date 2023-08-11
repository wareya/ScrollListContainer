tool
class_name ScrollListContainer
extends Container

var scrollbar_v : VScrollBar = null
var scrollbar_h : HScrollBar = null
var scroll_offset : Vector2 = Vector2()

func _check_scrollbars():
    if scrollbar_v == null:
        scrollbar_v = VScrollBar.new()
        scrollbar_v.name = "_scrollbar_v"
        add_child(scrollbar_v)
        scrollbar_v.show_on_top = true
    if scrollbar_h == null:
        scrollbar_h = HScrollBar.new()
        scrollbar_h.name = "_scrollbar_h"
        add_child(scrollbar_h)
        scrollbar_h.show_on_top = true

func _init():
    set_notify_transform(true)
    _check_scrollbars()
    
    var _unused = scrollbar_h.connect("value_changed", self, "_scroll")
    _unused = scrollbar_v.connect("value_changed", self, "_scroll")
    _unused = connect("sort_children", self, "_reflow")
    
    set_clip_contents(true)

func _ready():
    var _unused = get_viewport().connect("gui_focus_changed", self, "_check_focus")
    _fix_bg()

enum ALIGN {
    ALIGN_START,
    ALIGN_MIDDLE,
    ALIGN_END,
}

export var vertical : bool = true setget set_vertical
export var follow_focus : bool = true setget set_follow_focus

export var spacing : float = 0.0 setget set_spacing
export var initial_spacing : float = 0.0 setget set_initial_spacing
export var side_margin : float = 0.0 setget set_side_margin

export var auto_hide_scrollbars : bool = true setget set_autohide

export var background_texture : Texture = null setget set_bg
export var background_inner_rect : Rect2 = Rect2() setget set_bg_rect

func set_bg(_background_texture):
    background_texture = _background_texture
    if is_inside_tree():
        _fix_bg()
    update()

func set_bg_rect(_background_inner_rect):
    background_inner_rect = _background_inner_rect
    if is_inside_tree():
        _fix_bg()
    update()

func set_follow_focus(_follow_focus):
    follow_focus = _follow_focus
    queue_sort()
    update()

func set_vertical(_vertical):
    vertical = _vertical
    queue_sort()
    update()

func set_spacing(_spacing):
    spacing = _spacing
    queue_sort()
    update()

func set_side_margin(_margin):
    side_margin = _margin
    queue_sort()
    update()

func set_initial_spacing(_initial_spacing):
    initial_spacing = _initial_spacing
    queue_sort()
    update()

func set_autohide(_autohide):
    auto_hide_scrollbars = _autohide
    queue_sort()
    update()

func _scroll(_unused):
    if !vertical:
        scroll_offset.x = scrollbar_h.value
    else:
        scroll_offset.y = scrollbar_v.value
    queue_sort()
    update()

func _check_focus(focus_owner : Control):
    if !follow_focus:
        return
    if !focus_owner or !is_instance_valid(focus_owner) or !is_a_parent_of(focus_owner):
        return
    var focus_rect : Rect2 = focus_owner.get_rect()
    var rect : Rect2 = get_rect()
    rect.position = Vector2()
    
    if vertical:
        focus_rect.position.y -= initial_spacing
        focus_rect.end.y += initial_spacing*2.0
        if focus_rect.end.y > rect.end.y:
            scrollbar_v.value += focus_rect.end.y - rect.end.y
        elif focus_rect.position.y < rect.position.y:
            scrollbar_v.value += focus_rect.position.y - rect.position.y
    else:
        focus_rect.position.x -= initial_spacing
        focus_rect.end.x += initial_spacing*2.0
        if focus_rect.end.x > rect.end.x:
            scrollbar_h.value += focus_rect.end.x - rect.end.x
        elif focus_rect.position.x < rect.position.x:
            scrollbar_h.value += focus_rect.position.x - rect.position.x

func _notification(what):
    # fix background transform/size and draw index if anything changes
    if what in [NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_RESIZED, NOTIFICATION_MOVED_IN_PARENT, NOTIFICATION_DRAW]:
        _fix_bg()
    
    # clean up the background when we get deleted
    if what == NOTIFICATION_PREDELETE:
        if _sibling_ci_rid:
            VisualServer.free_rid(_sibling_ci_rid)
            _sibling_ci_rid = null
    
    # keep scrollbars drawing above contents
    # we don't get a notification when our children change -- but it DOES trigger a redraw
    if what == NOTIFICATION_DRAW:
        var child_count = get_child_count()
        if scrollbar_v:
            var v_pos = scrollbar_v.get_position_in_parent()
            if v_pos+2 < child_count:
                move_child(scrollbar_v, child_count-1)
        if scrollbar_h:
            var h_pos = scrollbar_h.get_position_in_parent()
            if h_pos+2 < child_count:
                move_child(scrollbar_h, child_count-1)

func _get_parent_canvasitem_of(node : CanvasItem) -> CanvasItem:
    var p = node.get_parent()
    if p and p is CanvasItem:
        return p
    elif p:
        return _get_parent_canvasitem_of(p)
    else:
        return null

func _calculate_bg_rect():
    var t = background_texture
    if t:
        var tex_size : Vector2 = t.get_size()
        var left = background_inner_rect.position.x
        var top = background_inner_rect.position.y
        var right = tex_size.x - background_inner_rect.end.x
        var bottom = tex_size.y - background_inner_rect.end.y
        var pos = Vector2(-left, -top)
        var _bg_extra_size = Vector2()
        _bg_extra_size.x = left + right
        _bg_extra_size.y = top + bottom
        var _bg_rect_size = rect_size + _bg_extra_size
        return Rect2(pos, _bg_rect_size)
    else:
        return get_rect()

var _sibling_ci_rid = null
func _fix_bg():
    if _sibling_ci_rid == null:
        _sibling_ci_rid = VisualServer.canvas_item_create()
    
    var rid = _sibling_ci_rid
    VisualServer.canvas_item_clear(rid)
    
    if !visible:
        return
    
    var parent = _get_parent_canvasitem_of(self)
    
    var self_rid = get_canvas_item()
    var parent_rid = get_canvas()
    if parent:
        parent_rid = parent.get_canvas_item()
    
    VisualServer.canvas_item_set_parent(rid, parent_rid)
    VisualServer.canvas_item_set_transform(rid, get_transform())
    VisualServer.canvas_item_set_draw_index(rid, get_index()-1)
    
    var t = background_texture
    var s = Rect2(Vector2(), t.get_size())
    var r = _calculate_bg_rect()
    var p = background_inner_rect.position
    var d = s.size - background_inner_rect.end
    VisualServer.canvas_item_add_nine_patch(rid, r, s, t, p, d)

func _do_reflow(visible_scroll : bool):
    _check_scrollbars()
    
    var cursor : Vector2 = Vector2()
    var raw_rect : Rect2 = get_rect()
    var rect : Rect2 = raw_rect
    rect.position = Vector2()
    
    if vertical:
        scroll_offset.x = 0
        scrollbar_h.hide()
        if visible_scroll:
            var scroll_size = scrollbar_v.get_combined_minimum_size().x
            scrollbar_v.show()
            fit_child_in_rect(scrollbar_v, Rect2(rect.size.x - scroll_size, 0, scroll_size, rect.size.y))
            rect.size.x -= scroll_size
    else:
        scroll_offset.y = 0
        scrollbar_v.hide()
        if visible_scroll:
            var scroll_size = scrollbar_h.get_combined_minimum_size().y
            scrollbar_h.show()
            fit_child_in_rect(scrollbar_h, Rect2(0, rect.size.y - scroll_size, rect.size.x, scroll_size))
            rect.size.y -= scroll_size
    
    if vertical:
        rect.position.x += side_margin
        rect.size.x -= side_margin*2.0
        cursor.y += initial_spacing
    else:
        rect.position.y += side_margin
        rect.size.y -= side_margin*2.0
        cursor.x += initial_spacing
    
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
                cursor.y = child.get_rect().end.y + spacing
            else:
                cursor.x = child.get_rect().end.x + spacing
            child.rect_position -= scroll_offset
        elif _child is Node2D:
            var child : Node2D = _child
            child.position = cursor
            child.position -= scroll_offset
    
    var c = cursor
    if vertical:
        cursor.y += initial_spacing
        cursor.y -= spacing
    else:
        cursor.x += initial_spacing
        cursor.x -= spacing
    
    if vertical:
        scrollbar_v.max_value = max(rect.size.y, cursor.y)
        scrollbar_v.page = rect.size.y
    else:
        scrollbar_h.max_value = max(rect.size.x, cursor.x)
        scrollbar_h.page = rect.size.x
    
    if visible_scroll:
        return true
    else:
        if vertical:
            return scrollbar_v.value == 0.0 and scrollbar_v.max_value <= scrollbar_v.page
        else:
            return scrollbar_h.value == 0.0 and scrollbar_h.max_value <= scrollbar_h.page

func _reflow():
    if auto_hide_scrollbars:
        var no_overflow = _do_reflow(false)
        if !no_overflow:
            _do_reflow(true)
        else:
            scrollbar_v.hide()
            scrollbar_h.hide()
    else:
        _do_reflow(true)
    
    _fix_bg()
