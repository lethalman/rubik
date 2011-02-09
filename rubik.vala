/* rubik.vala - Rubik 3D game
 *
 * Copyright © 2011  Luca Bruno
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 *   Luca Bruno  <lethalman88@gmail.com>
 */

using Clutter;
using Cogl;

Controller controller;

enum FaceNormal
  {
    FRONT,
    BACK,
    LEFT,
    RIGHT,
    TOP,
    BOTTOM;

    public FaceNormal rotate_x (FaceNormal reference)
    {
      if (reference == TOP || reference == BOTTOM)
        {
          if (this == FRONT || this == BACK)
            return this;
          if (this == TOP)
            return RIGHT;
          if (this == RIGHT)
            return BOTTOM;
          if (this == BOTTOM)
            return LEFT;
          if (this == LEFT)
            return TOP;
        }
      else
        {
          if (this == TOP || this == BOTTOM)
            return this;
          if (this == FRONT)
            return RIGHT;
          if (this == RIGHT)
            return BACK;
          if (this == BACK)
            return LEFT;
          if (this == LEFT)
            return FRONT;
        }
      assert_not_reached ();
    }

    public FaceNormal rotate_y (FaceNormal reference)
    {
      if (reference == LEFT || reference == RIGHT)
        {
          if (this == FRONT || this == BACK)
            return this;
          if (this == TOP)
            return RIGHT;
          if (this == RIGHT)
            return BOTTOM;
          if (this == BOTTOM)
            return LEFT;
          if (this == LEFT)
            return TOP;
        }
      else
        {
          if (this == LEFT || this == RIGHT)
            return this;
          if (this == FRONT)
            return TOP;
          if (this == TOP)
            return BACK;
          if (this == BACK)
            return BOTTOM;
          if (this == BOTTOM)
            return FRONT;
        }
      assert_not_reached ();
    }
  }

enum FaceColor
  {
    GREEN,
    YELLOW,
    RED,
    ORANGE,
    WHITE,
    BLUE;

    public Clutter.Color to_clutter ()
    {
      if (this == ORANGE)
        {
          var res = Clutter.Color ();
          res.red = 0xff; res.green = 0x8b; res.blue = 0; res.alpha = 255;
          return res;
        }
      var cls = (EnumClass) typeof(FaceColor).class_ref ();
      unowned string nick = cls.get_value (this).value_nick;
      return Clutter.Color.from_string (nick);
    }
  }

class MiniFaceFake : Rectangle
{
  private Matrix matrix;

  public MiniFaceFake (MiniFace face)
    {
      x = face.cube.x + face.mini_cube.x + face.x;
      y = face.cube.y + face.mini_cube.y + face.y;
      depth = face.cube.depth + face.mini_cube.depth + face.depth;
      width = face.width;
      height = face.height;
      matrix = face.cube.get_transformation_matrix ();
      matrix = Matrix.multiply (matrix, face.mini_cube.get_transformation_matrix ());
      matrix = Matrix.multiply (matrix, face.get_transformation_matrix ());
      set_parent (face.get_stage ());
      allocate (ActorBox (){x1=x, x2=x+width, y1=y, y2=y+height}, AllocationFlags.ALLOCATION_NONE);
    }

  public override void apply_transform (ref Matrix matrix)
  {
    matrix = Matrix.multiply (matrix, this.matrix);
  }
}

class MiniFace : Rectangle
{
  public FaceNormal normal;
  public FaceColor face_color;
  public weak MiniCube mini_cube { get { return (MiniCube) get_parent(); } }
  public weak Cube cube { get { return mini_cube.cube; } }

  public MiniFace (FaceNormal normal, FaceColor color)
  {
    GLib.Object (color: color.to_clutter (), border_color: Clutter.Color.from_string ("black"), border_width: 1);
    this.face_color = color;
    this.normal = normal;
    this.reactive = true;
  }

  public MiniFace.from_json (Json.Node node)
  {
    unowned Json.Object object = node.get_object ();
    this ((FaceNormal) object.get_int_member ("normal"),
          (FaceColor) object.get_int_member ("color"));
  }

  public Actor clone ()
  {
    return new MiniFaceFake (this);
  }

  public override void allocate (ActorBox box, AllocationFlags flags)
  {
    var width = box.x2 - box.x1;
    var height = box.y2 - box.y1;
    depth = 0;
    if (normal == FaceNormal.RIGHT)
      {
        box.x1 += width;
        box.x2 += width;
      }
    else if (normal == FaceNormal.BOTTOM)
      {
        box.y1 += height;
        box.y2 += height;
      }
    else if (normal == FaceNormal.BACK)
      depth = -width;

    set_rotation (RotateAxis.X_AXIS, 0, 0, 0, 0);
    set_rotation (RotateAxis.Y_AXIS, 0, 0, 0, 0);
    set_rotation (RotateAxis.Z_AXIS, 0, 0, 0, 0);
    if (normal == FaceNormal.RIGHT)
      set_rotation (RotateAxis.Y_AXIS, 90, 0, 0, 0);
    else if (normal == FaceNormal.LEFT)
      set_rotation (RotateAxis.Y_AXIS, 90, 0, 0, 0);
    else if (normal == FaceNormal.TOP)
      set_rotation (RotateAxis.X_AXIS, -90, 0, 0, 0);
    else if (normal == FaceNormal.BOTTOM)
      set_rotation (RotateAxis.X_AXIS, -90, 0, 0, 0);

    base.allocate (box, flags);
  }

  public MiniCube[] get_x_cubes ()
  {
    var res = new MiniCube[9];
    RotateAxis fixed_axis;
    if (normal == FaceNormal.TOP || normal == FaceNormal.BOTTOM)
      fixed_axis = RotateAxis.Z_AXIS;
    else
      fixed_axis = RotateAxis.Y_AXIS;

    var nth_set = 0;
    foreach (var mc in cube.mini_cubes)
      {
        if (fixed_axis == RotateAxis.Z_AXIS && mc.z_index == mini_cube.z_index ||
            fixed_axis == RotateAxis.Y_AXIS && mc.y_index == mini_cube.y_index)
          res[nth_set++] = mc;
        if (nth_set == 9)
          break;
      }
    return res;
  }

  public MiniCube[] get_y_cubes ()
  {
    var res = new MiniCube[9];
    RotateAxis fixed_axis;
    if (normal == FaceNormal.LEFT || normal == FaceNormal.RIGHT)
      fixed_axis = RotateAxis.Z_AXIS;
    else
      fixed_axis = RotateAxis.X_AXIS;

    var nth_set = 0;
    foreach (var mc in cube.mini_cubes)
      {
        if (fixed_axis == RotateAxis.Z_AXIS && mc.z_index == mini_cube.z_index ||
            fixed_axis == RotateAxis.X_AXIS && mc.x_index == mini_cube.x_index)
          res[nth_set++] = mc;
        if (nth_set == 9)
          break;
      }
    return res;
  }

  // clockwise rotation
  public void rotate_x (int times)
  {
    MiniCube[] cubes = get_x_cubes ();
    var orig_normal = normal;
    for (int time = 0; time < times; time++)
      {
        foreach (var mini_cube in cubes)
          {
            if (orig_normal == FaceNormal.TOP || orig_normal == FaceNormal.BOTTOM)
              {
                var old_x = mini_cube.x_index;
                mini_cube.x_index = 2 - mini_cube.y_index;
                mini_cube.y_index = old_x;
              } 
            else
              {
                var old_z = mini_cube.z_index;
                mini_cube.z_index = mini_cube.x_index;
                mini_cube.x_index = 2 - old_z;
              }
            foreach (var mini_face in mini_cube.mini_faces)
              mini_face.normal = mini_face.normal.rotate_x (orig_normal);
          }
      }

    cube.queue_relayout ();
  }

  // clockwise rotation
  public void rotate_y (int times)
  {
    MiniCube[] cubes = get_y_cubes ();
    var orig_normal = normal;
    for (int time = 0; time < times; time++)
      {
        foreach (var mini_cube in cubes)
          {
            if (orig_normal == FaceNormal.LEFT || orig_normal == FaceNormal.RIGHT)
              {
                var old_y = mini_cube.y_index;
                mini_cube.y_index = mini_cube.x_index;
                mini_cube.x_index = 2 - old_y;
              }
            else
              {
                var old_y = mini_cube.y_index;
                mini_cube.y_index = mini_cube.z_index;
                mini_cube.z_index = 2 - old_y;
              }
            foreach (var mini_face in mini_cube.mini_faces)
              mini_face.normal = mini_face.normal.rotate_y (orig_normal);
          }
      }

    cube.queue_relayout ();
  }

  public Json.Node serialize ()
  {
    var node = new Json.Node (Json.NodeType.OBJECT);
    var object = new Json.Object ();
    object.set_int_member ("normal", normal);
    object.set_int_member ("color", face_color);
    node.take_object ((owned) object);
    return (owned) node;
  }
}

class MiniCube : Actor
{
  public int x_index;
  public int y_index;
  public int z_index;
  public MiniFace[] mini_faces;

  public weak Cube cube { get { return (Cube) get_parent(); } }

  public MiniCube (int x, int y, int z, owned MiniFace[] mini_faces)
  {
    x_index = x;
    y_index = y;
    z_index = z;
    foreach (var mini_face in mini_faces)
      mini_face.set_parent (this);
    this.mini_faces = (owned) mini_faces;
    queue_relayout ();
  }

  public MiniCube.from_json (Json.Node node)
  {
    unowned Json.Object object = node.get_object ();
    unowned Json.Array array = object.get_array_member ("faces");
    var mini_faces = new MiniFace[array.get_length ()];
    for (var i=0; i < array.get_length (); i++)
      mini_faces[i] = new MiniFace.from_json (array.get_element (i));
    this ((int) object.get_int_member ("x"), (int) object.get_int_member ("y"), (int) object.get_int_member ("z"),
          (owned) mini_faces);
  }

  public override void allocate (ActorBox box, AllocationFlags flags)
  {
    base.allocate (box, flags);
    var x = -width * (x_index - 1) + width/2;
    var y = -width * (y_index - 1) + width/2;
    var z = width * (z_index - 1) - width/2;
    set_rotation (RotateAxis.X_AXIS, 0, x, y, z);
    set_rotation (RotateAxis.Y_AXIS, 0, x, y, z);
    set_rotation (RotateAxis.Z_AXIS, 0, x, y, z);
    foreach (var mini_face in mini_faces)
      {
        var mini_box = ActorBox ();
        mini_box.x1 = 0;
        mini_box.x2 = width;
        mini_box.y1 = 0;
        mini_box.y2 = height;
        mini_face.allocate (mini_box, flags);
      }
  }

  public override void pick (Clutter.Color color)
  {
    foreach (var mini_face in mini_faces)
      mini_face.paint ();
  }

  public override void paint ()
  {
    // draw a black cube    
    Cogl.set_source_color4ub (0, 0, 0, 255);
    // front face
    Cogl.translate (0, 0, -1);
    Cogl.rectangle (0, 0, width, height);
    Cogl.translate (0, 0, 1);
    // left face
    Cogl.rotate (90, 0, 1, 0);
    Cogl.translate (0, 0, 1);
    Cogl.rectangle (0, 0, width, height);
    Cogl.translate (0, 0, width-2);
    Cogl.rectangle (0, 0, width, height);
    Cogl.translate (0, 0, 1-width);
    Cogl.rotate (-90, 0, 1, 0);
    // back face
    Cogl.translate (0, 0, 1-width);
    Cogl.rectangle (0, 0, width, height);
    Cogl.translate (0, 0, width-1);
    // top face
    Cogl.rotate (-90, 1, 0, 0);
    Cogl.translate (0, 0, 1);
    Cogl.rectangle (0, 0, width, height);
    // bottom face
    Cogl.translate (0, 0, height-2);
    Cogl.rectangle (0, 0, width, height);
    Cogl.translate (0, 0, 1-height);
    Cogl.rotate (90, 1, 0, 0);

    foreach (var mini_face in mini_faces)
      mini_face.paint ();
  }

  public override void map ()
  {
    base.map ();
    foreach (var mini_face in mini_faces)
      mini_face.map ();
  }

  public override void unmap ()
  {
    base.unmap ();
    foreach (var mini_face in mini_faces)
      mini_face.unmap ();
  }

  public override void realize ()
  {
    foreach (var mini_face in mini_faces)
      mini_face.realize ();
  }

  public override void unrealize ()
  {
    foreach (var mini_face in mini_faces)
      mini_face.unrealize ();
  }

  public override void show_all ()
  {
    show ();
    foreach (var mini_face in mini_faces)
      mini_face.show_all ();
  }

  public override void hide_all ()
  {
    hide ();
    foreach (var mini_face in mini_faces)
      mini_face.hide_all ();
  }

  public Json.Node serialize ()
  {
    var node = new Json.Node (Json.NodeType.OBJECT);
    var object = new Json.Object ();
    object.set_int_member ("x", x_index);
    object.set_int_member ("y", y_index);
    object.set_int_member ("z", z_index);
    var array = new Json.Array ();
    foreach (var mini_face in mini_faces)
      array.add_element (mini_face.serialize ());
    object.set_array_member ("faces", array);
    node.take_object ((owned) object);
    return (owned) node;
  }
}

class Cube : Actor
{
  public MiniCube[] mini_cubes;
  public Matrix rotation_matrix = Matrix.identity ();
  public Vertex rotation_axis;
  private float _rotation_axis_angle;
  public float rotation_axis_angle { get { return _rotation_axis_angle; } set { _rotation_axis_angle = value; queue_redraw (); } }
  private float _rotation_axis_angle_after;
  public float rotation_axis_angle_after { get { return _rotation_axis_angle_after; } set { _rotation_axis_angle_after = value; queue_redraw (); } }
  public Rand rand = new Rand.with_seed ((int32) time_t ());

  construct
  {
    mini_cubes = new MiniCube[3*3*3];
    for (int x=0; x < 3; x++)
      {
        for (int y=0; y < 3; y++)
          {
            for (int z=0; z < 3; z++)
              {
                var mini_faces = new MiniFace[0];
                if (x == 0)
                  mini_faces += new MiniFace (FaceNormal.LEFT, FaceColor.WHITE);
                if (y == 0)
                  mini_faces += new MiniFace (FaceNormal.TOP, FaceColor.YELLOW);
                if (z == 0)
                  mini_faces += new MiniFace (FaceNormal.FRONT, FaceColor.RED);
                if (x == 2)
                  mini_faces += new MiniFace (FaceNormal.RIGHT, FaceColor.BLUE);
                if (y == 2)
                  mini_faces += new MiniFace (FaceNormal.BOTTOM, FaceColor.GREEN);
                if (z == 2)
                  mini_faces += new MiniFace (FaceNormal.BACK, FaceColor.ORANGE);

                var mini_cube = new MiniCube (x, y, z, (owned) mini_faces);
                mini_cube.set_parent (this);
                mini_cubes[x+y*3+z*9] = mini_cube;
              }
          }
      }
    queue_relayout ();
  }

  public void shuffle ()
  {
    foreach (var mini_cube in mini_cubes)
      {
        foreach (var mini_face in mini_cube.mini_faces)
          {
            mini_face.rotate_x (rand.int_range (0, 4));
            mini_face.rotate_y (rand.int_range (0, 4));
          }
      }
  }

  public override void apply_transform (ref Matrix matrix)
  {
    base.apply_transform (ref matrix);
    // can't use euler angles, looks like clutter has some other strange convention
    var m = Matrix.identity ();
    m.translate (width/2, height/2, -width/2);
    m.rotate (_rotation_axis_angle, rotation_axis.x, rotation_axis.y, rotation_axis.z);
    m.translate (-width/2, -height/2, width/2);
    m = Matrix.multiply (m, rotation_matrix);
    m.translate (width/2, height/2, -width/2);
    m.rotate (_rotation_axis_angle_after, rotation_axis.x, rotation_axis.y, rotation_axis.z);
    m.translate (-width/2, -height/2, width/2);
    matrix = Matrix.multiply (matrix, m);
  }

  public void save_rotation ()
  {
    var m = Matrix.identity ();
    m.translate (width/2, height/2, -width/2);
    m.rotate (_rotation_axis_angle, rotation_axis.x, rotation_axis.y, rotation_axis.z);
    m.translate (-width/2, -height/2, width/2);
    m = Matrix.multiply (m, rotation_matrix);    
    m.translate (width/2, height/2, -width/2);
    m.rotate (_rotation_axis_angle_after, rotation_axis.x, rotation_axis.y, rotation_axis.z);
    m.translate (-width/2, -height/2, width/2);
    rotation_matrix = m;
    _rotation_axis_angle = 0;
    _rotation_axis_angle_after = 0;
  }

  public override void allocate (ActorBox box, AllocationFlags flags)
  {
    base.allocate (box, flags);
    var mini_width = width/3;
    var mini_height = height/3;
    foreach (var mini_cube in mini_cubes)
    {
      mini_cube.depth = depth - (mini_width) * mini_cube.z_index;
      var mini_box = ActorBox ();
      mini_box.x1 = (mini_width) * mini_cube.x_index;
      mini_box.x2 = mini_box.x1 + mini_width;
      mini_box.y1 = (mini_height) * mini_cube.y_index;
      mini_box.y2 = mini_box.y1 + mini_height;
      mini_cube.allocate (mini_box, AllocationFlags.ABSOLUTE_ORIGIN_CHANGED);
    }
  }

  public override void pick (Clutter.Color color)
  {
    Cogl.set_depth_test_enabled (true);
    foreach (var mini_cube in mini_cubes)
      mini_cube.paint ();
    Cogl.set_depth_test_enabled (false);
  }

  public override void paint ()
  {
    Cogl.set_depth_test_enabled (true);
    foreach (var mini_cube in mini_cubes)
      mini_cube.paint ();
    Cogl.set_depth_test_enabled (false);
  }

  public override void map ()
  {
    base.map ();
    foreach (var mini_cube in mini_cubes)
      mini_cube.map ();
  }

  public override void unmap ()
  {
    base.unmap ();
    foreach (var mini_cube in mini_cubes)
      mini_cube.unmap ();
  }

  public override void realize ()
  {
    foreach (var mini_cube in mini_cubes)
      mini_cube.realize ();
  }

  public override void unrealize ()
  {
    foreach (var mini_cube in mini_cubes)
      mini_cube.unrealize ();   
  }

  public override void show_all ()
  {
    show ();
    foreach (var mini_cube in mini_cubes)
      mini_cube.show_all ();
  }

  public override void hide_all ()
  {
    hide ();
    foreach (var mini_cube in mini_cubes)
      mini_cube.hide_all ();
  }

  public Json.Node serialize ()
  {
    var node = new Json.Node (Json.NodeType.OBJECT);
    var object = new Json.Object ();
    var array = new Json.Array ();
    foreach (var mini_cube in mini_cubes)
      array.add_element (mini_cube.serialize ());
    object.set_array_member ("cubes", array);
    object.set_member ("rotation", serialize_matrix (rotation_matrix));
    node.take_object ((owned) object);
    return (owned) node;
  }

  public void deserialize (Json.Node node)
  {
    unowned Json.Object object = node.get_object ();
    unowned Json.Array array = object.get_array_member ("cubes");
    if (array.get_length () != mini_cubes.length)
      {
        warning ("Corrupted file format");
        return;
      }
    for (var i=0; i < array.get_length (); i++)
      {
        mini_cubes[i] = new MiniCube.from_json (array.get_element (i));
        mini_cubes[i].set_parent (this);
      }
    unowned Json.Node rotation = object.get_member ("rotation");
    rotation_matrix = deserialize_matrix (rotation);
    queue_relayout ();
  }
}

class Controller
{
  public MiniFace face;
  public Actor clone;
  public float orig_x;
  public float orig_y;
  public float orig_actor_x;
  public float orig_actor_y;
  public MiniCube[] cubes;
  public bool is_x_rotation;
  public int rotation_times;
  public uint button;
  public bool has_first_point = false;
  public bool pressed = false;
  public weak Cube cube;
  public weak Stage stage;

  public Controller (Cube cube, Text shuffle)
  {
    this.cube = cube;
    this.stage = cube.get_stage ();
    shuffle.reactive = true;
    shuffle.button_press_event.connect (() => { cube.shuffle (); return true; });
    stage.button_press_event.connect (on_button_press_event);
    stage.button_release_event.connect (on_button_release_event);
    stage.key_press_event.connect (on_key_press_event);
    stage.motion_event.connect (on_motion_event);
  }

  public bool on_key_press_event (KeyEvent event)
  {
    // a=97, w=119, d=100, s=115
    if (event.keyval == 65307) // ESC
      {
        cube.rotation_matrix = Matrix.identity ();
        cube.queue_redraw ();
        return true;
      }
    else if (event.keyval == 'a')
      cube.rotation_axis = Vertex(){x=0, y=-1, z=0};
    else if (event.keyval == 'w')
      cube.rotation_axis = Vertex(){x=1, y=0, z=0};
    else if (event.keyval == 'd')
      cube.rotation_axis = Vertex(){x=0, y=1, z=0};
    else if (event.keyval == 's')
      cube.rotation_axis = Vertex(){x=-1, y=0, z=0};
    else if (event.keyval == 'q')
      cube.rotation_axis = Vertex(){x=0, y=0, z=-1};
    else if (event.keyval == 'e')
      cube.rotation_axis = Vertex(){x=0, y=0, z=1};
    else
      return false;
    cube.animate (AnimationMode.LINEAR, 100, "rotation-axis-angle-after", 90.0).completed.connect_after (() => cube.save_rotation ());
    return true;
  }

  public bool on_button_press_event (ButtonEvent event)
  {
    orig_x = event.x;
    orig_y = event.y;
    has_first_point = true;
    this.button = event.button;
    if (button == 1)
      {
        var face = event.stage.get_actor_at_pos (PickMode.REACTIVE, (int) event.x, (int) event.y) as MiniFace;
        if (face == null)
          {
            // allow rotation
            this.button = 0;
            pressed = true;
            return true;
          }
        this.face = face;
        clone = face.clone ();
        clone.transform_stage_point (event.x, event.y, out orig_actor_x, out orig_actor_y);
      }
    pressed = true;
    return true;
  }

  private void clear_rotation ()
  {
    foreach (var mini_cube in cubes)
    {
      mini_cube.rotation_angle_x = 0;
      mini_cube.rotation_angle_y = 0;
      mini_cube.rotation_angle_z = 0;
    }
  }

  public bool on_button_release_event (ButtonEvent event)
  {
    pressed = false;
    has_first_point = false;
    if (button != 1)
      {
        cube.save_rotation ();
        return true;
      }
    var timeline = new Timeline (100);
    foreach (var mini_cube in cubes)
      {
        float xangle, yangle;
        string xaxis, yaxis;
        get_slice_rotation (event.x, event.y, null, null, null, out xangle, out yangle, null, null, out xaxis, out yaxis);
        if (is_x_rotation)
          {
            var xround = Math.roundf (xangle / 90) * 90;
            mini_cube.animate_with_timeline (AnimationMode.LINEAR, timeline, xaxis, xround);
          }
        else
          {
            var yround = Math.roundf (yangle / 90) * 90;
            mini_cube.animate_with_timeline (AnimationMode.LINEAR, timeline, yaxis, yround);
          }
      }
    timeline.start ();
    var rot_times = rotation_times;
    if (is_x_rotation)
      timeline.completed.connect_after (() => face.rotate_x (rot_times));
    else
      timeline.completed.connect_after (() => face.rotate_y (rot_times));
    cubes = null;
    rotation_times = 0;
    return true;
  }

  // VALA BUG for out parameters
  private void get_slice_rotation (float event_x, float event_y, out float? r_distance, out float? r_orig_xabs, out float? r_orig_yabs, out float? r_xangle, out float? r_yangle, out float? r_xabs, out float? r_yabs, out string? xaxis, out string? yaxis)
  {
    var distance = Math.sqrtf (Math.powf ((event_x - orig_x), 2) + Math.powf ((event_y - orig_y), 2));
    float x, y;
    clone.transform_stage_point (event_x, event_y, out x, out y);
    var xangle = x - orig_actor_x;
    var yangle = y - orig_actor_y;
    var orig_xabs = Math.fabsf (xangle);
    var orig_yabs = Math.fabsf (yangle);

    // limit xangle so that it doesn't screw up the user
    xangle = xangle > 0 ? float.min (xangle, distance) : float.max (xangle, -distance);
    yangle = yangle > 0 ? float.min (yangle, distance) : float.max (yangle, -distance);
    xangle = xangle > 0 ? float.min (xangle, 270) : float.max (xangle, -270);
    yangle = yangle > 0 ? float.min (yangle, 270) : float.max (yangle, -270);
    yangle = -yangle;

    var xabs = Math.fabsf (xangle);
    var yabs = Math.fabsf (yangle);

    switch (face.normal)
    {
    case FaceNormal.FRONT:
      xaxis = "rotation_angle_y";
      yaxis = "rotation_angle_x";
      break;
    case FaceNormal.RIGHT:
      xaxis = "rotation_angle_y";
      yaxis = "rotation_angle_z";
      yangle = -yangle;
      break;
    case FaceNormal.LEFT:
      xaxis = "rotation_angle_y";
      yaxis = "rotation_angle_z";
      xangle = -xangle;
      break;
    case FaceNormal.BACK:
      xaxis = "rotation_angle_y";
      yaxis = "rotation_angle_x";
      xangle = -xangle;
      yangle = -yangle;
      break;
    case FaceNormal.TOP:
      xaxis = "rotation_angle_z";
      yaxis = "rotation_angle_x";
      yangle = -yangle;
      break;
    case FaceNormal.BOTTOM:
      xaxis = "rotation_angle_z";
      yaxis = "rotation_angle_x";
      xangle = -xangle;
      break;
    default:
      assert_not_reached ();
    }
    r_distance = distance;
    r_xangle = xangle;
    r_yangle = yangle;
    r_orig_xabs = orig_xabs;
    r_orig_yabs = orig_yabs;
    r_xabs = xabs;
    r_yabs = yabs;
  }

  private Vertex normalize (Vertex v)
  {
    var length = Math.sqrtf (v.x*v.x + v.y*v.y + v.z*v.z);
    if (length == 0)
      return v;
    return Vertex(){x=v.x/length, y=v.y/length, z=v.z/length};
  }

  private Vertex sphere_point (float x, float y)
  {
    // translate wrt sphere center
    var radius = float.max (stage.width, stage.height) * 2;
    var xoffset = (radius - stage.width)/2;
    var yoffset = (radius - stage.height)/2;
    x = (x+xoffset) / (radius / 2) - 1;
    y = (y+yoffset) / (radius / 2) - 1;
    var z = 1 - x*x - y*y;
    z = z > 0 ? Math.sqrtf (z) : 0;
    return Vertex(){x=x, y=y, z=z};
  }

  private float trackball_rotation (float x, float y, out Vertex axis)
  {
    // http://viewport3d.com/trackball.htm
    var v1 = normalize (sphere_point (orig_x, orig_y));
    var v2 = normalize (sphere_point (x, y));
    // angle between the two vectors
    var dot_product = v1.x*v2.x + v1.y*v2.y + v1.z*v2.z;
    var angle = Math.acosf (dot_product);
    // cross product
    axis = Vertex(){x=v1.y*v2.z-v1.z*v2.y, y=v1.z*v2.x-v1.x*v2.z, z=v1.x*v2.y-v1.y*v2.x};
    // don't transform to euler, clutter uses different convention
    return angle * 360;
  }

  public bool on_motion_event (MotionEvent event)
  {
    if ((pressed && button != 1) || ModifierType.SHIFT_MASK in event.modifier_state)
      {
        if (!has_first_point)
          {
            orig_x = event.x;
            orig_y = event.y;
            has_first_point = true;
          }
        cube.rotation_axis_angle = trackball_rotation (event.x, event.y, out cube.rotation_axis);
        return true;
      }

    if (!pressed)
      {
        if (has_first_point)
          {
            // rotating with shift
            cube.save_rotation ();
            has_first_point = false;
          }
        return false;
      }

    // rotate cube slice
    float distance, orig_xabs, orig_yabs, xangle, yangle, xabs, yabs;
    string xaxis, yaxis;
    get_slice_rotation (event.x, event.y, out distance, out orig_xabs, out orig_yabs, out xangle, out yangle, out xabs, out yabs, out xaxis, out yaxis);

    if (cubes == null)
      {
        // threshold
        if (distance < 10)
          return false;
        if (orig_xabs > orig_yabs)
          {
            cubes = face.get_x_cubes ();
            is_x_rotation = true;
          }
        else
          {
            cubes = face.get_y_cubes ();
            is_x_rotation = false;
          }
      }

    clear_rotation ();
    foreach (var mini_cube in cubes)
      {
        if (is_x_rotation)
          {
            rotation_times = (int) Math.roundf (xabs / 90);
            if (xangle < 0)
              rotation_times = 4 - rotation_times;
            mini_cube.set_property (xaxis, xangle);
          }
        else
          {
            rotation_times = (int) Math.roundf (yabs / 90);
            if (yangle < 0)
              rotation_times = 4 - rotation_times;
            mini_cube.set_property (yaxis, yangle);
          }
      }
    return true;
  }

  public void restore ()
  {
    try
      {
        var homedir = Environment.get_home_dir ();
        var filename = GLib.Path.build_filename (homedir, ".rubik");
        if (!FileUtils.test (filename, FileTest.EXISTS))
          return;
        var parser = new Json.Parser ();
        parser.load_from_file (filename);
        cube.deserialize (parser.get_root ());
      }
    catch (GLib.Error e)
    {
      warning ("Can't restore game: %s", e.message);
    }
  }

  public void save ()
  {
    try
      {
        var homedir = Environment.get_home_dir ();
        var filename = GLib.Path.build_filename (homedir, ".rubik");
        var node = cube.serialize ();
        var generator = new Json.Generator ();
        generator.set_root (node);
        generator.to_file (filename);
      }
    catch (GLib.Error e)
    {
      warning ("Can't save game: %s", e.message);
    }
  }
}

Json.Node serialize_matrix (Matrix m)
{
  var node = new Json.Node (Json.NodeType.ARRAY);
  var array = new Json.Array ();
  // use strings, json 0.10 bug
  array.add_string_element (m.xx.to_string ());
  array.add_string_element (m.yx.to_string ());
  array.add_string_element (m.zx.to_string ());
  array.add_string_element (m.wx.to_string ());
  array.add_string_element (m.xy.to_string ());
  array.add_string_element (m.yy.to_string ());
  array.add_string_element (m.zy.to_string ());
  array.add_string_element (m.wy.to_string ());
  array.add_string_element (m.xz.to_string ());
  array.add_string_element (m.yz.to_string ());
  array.add_string_element (m.zz.to_string ());
  array.add_string_element (m.wz.to_string ());
  array.add_string_element (m.xw.to_string ());
  array.add_string_element (m.yw.to_string ());
  array.add_string_element (m.zw.to_string ());
  array.add_string_element (m.ww.to_string ());
  node.take_array ((owned) array);
  return (owned) node;
}

Matrix deserialize_matrix (Json.Node node)
{
  unowned Json.Array array = node.get_array ();
  if (array.get_length () != 16)
    {
      warning ("Corrupted file format");
      return Matrix.identity ();
    }
  var values = new float[16];
  for (var i=0; i < 16; i++)
    values[i] = (float) array.get_string_element (i).to_double ();
  return Matrix.from_array (values);
}
  
void quit ()
{
  controller.save ();
  Process.exit (0);
}

void main (string[] args) {
  Clutter.init (ref args);
  unowned Stage stage = Stage.get_default ();
  stage.title = "Rubik 1.0";
  var c = Clutter.Color ();
  c.red = 0x18; c.green = 0x18; c.blue = 0x18; c.alpha = 0xff;
  stage.color = c;

  var cube = new Cube ();
  cube.set_size (240, 240);
  cube.anchor_gravity = Gravity.CENTER;
  cube.set_position (stage.width/2, stage.height/2);
  cube.show_all ();
  stage.add (cube);

  var shuffle = new Text.full ("Helvetica Bold 12", "Shuffle", Clutter.Color.from_string ("white"));
  shuffle.anchor_gravity = Gravity.CENTER;
  shuffle.set_position (stage.width-50, stage.height-30);
  stage.add (shuffle);

  controller = new Controller (cube, shuffle);
  controller.restore ();
  Process.signal (ProcessSignal.HUP, quit);
  Process.signal (ProcessSignal.INT, quit);
  Process.signal (ProcessSignal.QUIT, quit);
  Process.signal (ProcessSignal.KILL, quit);
  Process.signal (ProcessSignal.TERM, quit);

  stage.show ();
  Clutter.main ();

  quit ();
}
